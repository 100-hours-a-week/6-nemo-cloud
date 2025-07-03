#!/bin/bash
set -euo pipefail

# [인자 체크] 서비스명/환경/태그 필수
if [ $# -lt 3 ]; then
  echo "[rollback.sh] 사용법: $0 <서비스명(ai, backend 등)> <환경(dev, prod)> <롤백태그>" >&2
  exit 1
fi
RAW_SERVICE="$1"         # 예: ai-dev, backend, frontend
ENV="$2"                 # dev, prod
ROLLBACK_TAG="$3"        # 롤백할 이미지 태그 (예: 20240604-1802)

# [논리 서비스명 추출] (ai-dev → ai)
SERVICE=$(echo "$RAW_SERVICE" | cut -d'-' -f1)

# [Compose용 실제 서비스명/컴포즈 파일]
if [ "$SERVICE" = "ai" ]; then
  SERVICE_NAME="ai-${ENV}"
else
  SERVICE_NAME="$RAW_SERVICE"
fi

# [경로 설정]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/envs/${SERVICE}.${ENV}.env"

# [유틸 스크립트 불러오기]
source "$SCRIPT_DIR/utils.sh"

# [루트 디렉토리로 이동]
cd "$ROOT_DIR"

# [환경변수 로드]
echo "🔧 [$ENV] 환경변수 로드 중..."
if ! load_env "$SERVICE" "$ENV"; then
  echo "[rollback.sh] 환경변수 로드 실패: $SERVICE $ENV" >&2
  exit 1
fi

# [REGISTRY_URL 체크]
if [ -z "${REGISTRY_URL:-}" ]; then
  echo "[rollback.sh] REGISTRY_URL 환경변수가 비어 있습니다." >&2
  exit 1
fi

# [롤백 이미지 Pull]
ROLLBACK_IMAGE="$REGISTRY_URL/$SERVICE:$ROLLBACK_TAG"
echo "📥 롤백 이미지 Pull: $ROLLBACK_IMAGE"
docker pull "$ROLLBACK_IMAGE"

# [컨테이너 재생성]
echo "🚀 롤백 컨테이너 재생성 중..."
docker compose -f "docker-compose.${ENV}.yaml" stop "$SERVICE_NAME" || true
docker compose -f "docker-compose.${ENV}.yaml" rm -f "$SERVICE_NAME" || true
ROLLBACK_IMAGE="$ROLLBACK_IMAGE" docker compose -f "docker-compose.${ENV}.yaml" up -d --force-recreate --remove-orphans "$SERVICE_NAME"

# [롤백 후 헬스체크]
echo "🩺 롤백 후 헬스체크 수행 중..."
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
  notify_discord_all "$SERVICE" "✅ [롤백 성공: $ENV] $SERVICE_NAME 롤백 완료! (Rollback Tag: $ROLLBACK_TAG)"
  echo "🎉 [$SERVICE_NAME] 롤백 완료"
else
  notify_discord_all "$SERVICE" "❌ [롤백 실패: $ENV] $SERVICE_NAME 롤백 실패! (Rollback Tag: $ROLLBACK_TAG)"
  exit 1
fi
