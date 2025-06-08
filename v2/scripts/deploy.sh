#!/bin/bash
set -euo pipefail

SERVICE="$1"   # backend, frontend, ai
ENV="dev"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 [1] 환경변수 및 공통 함수 로드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
source "$HOME/nemo/cloud/v2/scripts/utils.sh"
load_env "$SERVICE"

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
  docker stop "$SERVICE_NAME" 2>/dev/null || true
  docker rm "$SERVICE_NAME" 2>/dev/null || true
  docker run -d --name "$SERVICE_NAME" \
    --env-file "$ENV_FILE" \
    -p "$PORT:$PORT" \
    "$IMAGE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🩺 [4] 헬스체크 수행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE"; then
  notify_discord_all "✅ [배포 성공: $BRANCH] $SERVICE_NAME 배포 완료!"
  echo ""
  echo "🎉 [$SERVICE_NAME] 배포 완료"
else
  notify_discord_all "❌ [배포 실패: $BRANCH] $SERVICE_NAME 배포 실패!"
  exit 1
fi
