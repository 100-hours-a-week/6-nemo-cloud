#!/bin/bash
set -euo pipefail

SERVICE="$1"   # backend, frontend, ai
ENV="$2"       # dev or prod

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 [1] 환경변수 및 공통 함수 로드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
source "$SCRIPT_DIR/utils.sh"

# dev = 서버 내 환경변수, prod = GCP Secret Manager
if [ "$ENV" == "dev" ]; then
  load_env "$SERVICE"
else
  echo "🔐 [prod] Secret Manager에서 환경변수 불러오는 중..."
  if SECRET_CONTENT=$(gcloud secrets versions access latest \
    --secret="${SERVICE}-${ENV}-env" \
    --project="${GCP_PROJECT_ID_PROD}"); then
    export $(echo "$SECRET_CONTENT" | xargs)
  else
    echo "❌ Secret Manager에서 환경변수 로딩 실패"
    exit 1
  fi
fi

cd "$ROOT_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 [2] 도커 이미지 Pull"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔁 이미지: $IMAGE"
docker pull "$IMAGE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 [3] 도커 컨테이너 실행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ENV" == "dev" ]; then
  docker compose up -d
else
  TEMPLATE_NAME="${SERVICE}-${ENV}-template-$(TZ=Asia/Seoul date +'%Y%m%d-%H%M')"
  
  # MIG 이름 결정
  if [ "$SERVICE" == "backend" ]; then
    MIG_NAME="be-instance-group"
  elif [ "$SERVICE" == "frontend" ]; then
    MIG_NAME="fe-instance-group"
  else
    echo "❌ [오류] '$SERVICE'는 지원되지 않는 서비스입니다 (backend, frontend만 가능)"
    exit 1
  fi

  echo "🏗️ 템플릿 생성 중: $TEMPLATE_NAME"
  gcloud compute instance-templates create "$TEMPLATE_NAME" \
    --machine-type="${MACHINE_TYPE:-e2-medium}" \
    --image-family="${IMAGE_FAMILY:-cos-stable}" \
    --image-project="${IMAGE_PROJECT:-cos-cloud}" \
    --network="v2-nemo-prod" \
    --subnet="prod-backend" \
    --region="${REGION}" \
    --no-address \
    --metadata=startup-script="#! /bin/bash
gcloud secrets versions access latest --secret=${SERVICE}-${ENV}-env > /root/.env
docker run -d --restart=always --env-file /root/.env -p ${PORT}:${PORT} ${IMAGE}" \
    --tags="${SERVICE}-${ENV}"

  echo "🔁 MIG 롤링 업데이트 중: $MIG_NAME"
  gcloud compute instance-groups managed rolling-action start-update "$MIG_NAME" \
    --version=template="projects/${GCP_PROJECT_ID_PROD}/global/instanceTemplates/${TEMPLATE_NAME}" \
    --region="${REGION}" \
    --project="${GCP_PROJECT_ID_PROD}" \
    --max-surge=2 \
    --max-unavailable=0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🩺 [4] 헬스체크 수행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
  notify_discord_all "✅ [배포 성공: $BRANCH] $SERVICE_NAME 배포 완료!"
  echo ""
  echo "🎉 [$SERVICE_NAME] 배포 완료"
else
  notify_discord_all "❌ [배포 실패: $BRANCH] $SERVICE_NAME 배포 실패!"
  exit 1
fi
