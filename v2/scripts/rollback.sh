#!/bin/bash
set -euo pipefail

SERVICE="$1"         # backend, frontend, ai
ENV="$2"             # dev, prod
ROLLBACK_TAG="$3"    # 롤백할 이미지 태그 (예: 20240604-1802)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 [1] 환경변수 및 공통 함수 로드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
source "$HOME/nemo/cloud/v2/scripts/utils.sh"
load_env "$SERVICE"

cd "$ROOT_DIR"

if [ -z "$ROLLBACK_TAG" ]; then
  echo "❌ 롤백할 태그가 없습니다. 인자로 태그명을 지정하세요."
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 [2] 롤백 대상 이미지 Pull"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ROLLBACK_IMAGE="$REGISTRY_URL/$SERVICE:$ROLLBACK_TAG"
echo "🔁 롤백 이미지: $ROLLBACK_IMAGE"
docker pull "$ROLLBACK_IMAGE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 [3] 컨테이너 재실행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ENV" == "dev" ]; then
  ROLLBACK_IMAGE="$ROLLBACK_IMAGE" docker compose up -d "$SERVICE_NAME"
else
  docker stop "$SERVICE_NAME" 2>/dev/null || true
  docker rm "$SERVICE_NAME" 2>/dev/null || true
  docker run -d --name "$SERVICE_NAME" \
    --env-file "$ENV_FILE" \
    -p "$PORT:$PORT" \
    "$ROLLBACK_IMAGE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🩺 [4] 롤백 후 헬스체크"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE"; then
  notify_discord_all "✅ [롤백 성공: $BRANCH] $SERVICE_NAME 롤백 완료! (Rollback Tag: $ROLLBACK_TAG)"
  echo ""
  echo "🎉 [$SERVICE_NAME] 롤백 완료"
else
  notify_discord_all "❌ [롤백 실패: $BRANCH] $SERVICE_NAME 롤백 실패! (Rollback Tag: $ROLLBACK_TAG)"
  exit 1
fi
