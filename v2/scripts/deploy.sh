#!/bin/bash
set -euo pipefail

SERVICE="$1"   # backend, frontend, ai
ENV="$2"       # dev or prod

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 [1] 환경변수 및 공통 함수 로드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
source "$SCRIPT_DIR/utils.sh"

# 환경변수 로드
if [ "$ENV" == "dev" ]; then
  echo "🔧 [dev] 로컬 환경변수 로드 중..."
  load_env "$SERVICE"
else
  echo "🔐 [prod] Secret Manager에서 환경변수 로드 중..."
  if SECRET_CONTENT=$(gcloud secrets versions access latest \
      --secret="${SERVICE}-${ENV}-env" \
      --project="${GCP_PROJECT_ID_PROD}"); then
    export $(echo "$SECRET_CONTENT" | xargs)
  else
    echo "❌ Secret Manager에서 환경변수 로딩 실패"
    exit 1
  fi
fi

# dev 환경 (docker-compose)
if [ "$ENV" == "dev" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🐳 [dev] 도커 컴포즈로 실행 중..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  docker compose -f docker-compose.dev.yaml pull "$SERVICE"
  docker compose -f docker-compose.dev.yaml up -d "$SERVICE"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🩺 [dev] 헬스체크 수행"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
    notify_discord_all "✅ [배포 성공: $BRANCH] $SERVICE 배포 완료!"
    echo "🎉 [$SERVICE] 개발 환경 배포 완료"
  else
    notify_discord_all "❌ [배포 실패: $BRANCH] $SERVICE 배포 실패!"
    exit 1
  fi

  exit 0
fi

# prod 환경 (instance template + MIG update)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️ [prod] 템플릿 생성 및 MIG 롤링 업데이트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

case "$SERVICE" in
  backend) MIG_NAME="be-instance-group" ;;
  frontend) MIG_NAME="fe-instance-group" ;;
  *)
    echo "❌ 지원되지 않는 서비스입니다: $SERVICE"
    exit 1
    ;;
esac

TEMPLATE_NAME="${SERVICE}-${ENV}-template-$(TZ=Asia/Seoul date +'%Y%m%d-%H%M')"

echo "🧱 템플릿 이름: $TEMPLATE_NAME"

STARTUP_SCRIPT_CMD="bash /home/ubuntu/nemo/cloud/v2/scripts/startup.sh ${SERVICE} ${ENV}"

gcloud compute instance-templates create "$TEMPLATE_NAME" \
  --region="${REGION}" \
  --machine-type="${MACHINE_TYPE}" \
  --image="${CUSTOM_IMAGE}" \
  --image-project="${GCP_PROJECT_ID_PROD}" \
  --network=projects/${GCP_PROJECT_ID_PROD}/global/networks/${NETWORK} \
  --subnet=projects/${GCP_PROJECT_ID_PROD}/regions/${REGION}/subnetworks/${SUBNET} \
  --no-address \
  --service-account="${SERVICE_ACCOUNT}" \
  --scopes="cloud-platform" \
  --tags="${SERVICE}-${ENV},frontend-prod,backend-prod" \
  --boot-disk-size="${BOOT_DISK_SIZE}GB" \
  --boot-disk-type="${BOOT_DISK_TYPE}" \
  --boot-disk-device-name=boot-disk \
  --metadata=startup-script="$STARTUP_SCRIPT_CMD"

echo "🔁 MIG 롤링 업데이트 시작: $MIG_NAME"

# MIG 롤링 업데이트
gcloud compute instance-groups managed rolling-action start-update "$MIG_NAME" \
  --version=template="${TEMPLATE_NAME}" \
  --region="${REGION}" \
  --minimal-action=REPLACE \
  --max-surge=2 \
  --max-unavailable=0
