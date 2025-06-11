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
  docker compose pull
  docker compose up -d

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

# 지역 인스턴스 템플릿 생성
gcloud compute instance-templates create "$TEMPLATE_NAME" \
  --instance-template-region="${REGION}" \
  --machine-type="${MACHINE_TYPE:-e2-medium}" \
  --image-family="${IMAGE_FAMILY:-cos-stable}" \
  --image-project="${IMAGE_PROJECT:-cos-cloud}" \
  --network="v2-nemo-prod" \
  --subnet="prod-backend" \
  --no-address \
  --service-account="${SERVICE_ACCOUNT}" \
  --scopes="cloud-platform" \
  --tags="${SERVICE}-${ENV}" \
  --boot-disk-size="${BOOT_DISK_SIZE}GB" \
  --boot-disk-type=pd-balanced \
  --boot-disk-device-name=boot-disk \
  --metadata=startup-script="#!/bin/bash
set -euo pipefail

echo '[startup] 환경변수 로딩'
if ! gcloud secrets versions access latest \
  --secret=${SERVICE}-${ENV}-env \
  --project=${GCP_PROJECT_ID_PROD} > /root/.env; then
  echo '[startup][ERROR] 환경변수 로딩 실패'
  exit 1
fi

echo '[startup] Docker 인증'
gcloud auth configure-docker asia-northeast3-docker.pkg.dev --quiet

echo '[startup] 이미지 Pull'
if ! docker pull ${IMAGE}; then
  echo '[startup][ERROR] 이미지 Pull 실패'
  exit 1
fi

echo '[startup] 컨테이너 실행'
if ! docker run -d --name ${SERVICE} --restart=always \
  --env-file /root/.env -p ${PORT}:${PORT} ${IMAGE}; then
  echo '[startup][ERROR] 컨테이너 실행 실패'
  docker logs ${SERVICE} || true
  exit 1
fi
"


echo "🔁 MIG 롤링 업데이트 시작: $MIG_NAME"

# MIG 롤링 업데이트
gcloud compute instance-groups managed rolling-action start-update "$MIG_NAME" \
  --version=template="projects/${GCP_PROJECT_ID_PROD}/regions/${REGION}/instanceTemplates/${TEMPLATE_NAME}" \
  --region="${REGION}" \
  --project="${GCP_PROJECT_ID_PROD}" \
  --max-surge=2 \
  --max-unavailable=0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🩺 [prod] 헬스체크 수행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
  notify_discord_all "✅ [배포 성공: $BRANCH] $SERVICE 배포 완료!"
  echo "🎉 [$SERVICE_NAME] 배포 완료"
else
  notify_discord_all "❌ [배포 실패: $BRANCH] $SERVICE 배포 실패!"
  exit 1
fi
