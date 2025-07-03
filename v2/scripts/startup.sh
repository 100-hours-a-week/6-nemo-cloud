#!/bin/bash
set -euo pipefail

# [인자 체크] 서비스명/환경 필수
if [ $# -lt 2 ]; then
  echo "[startup.sh] 사용법: $0 <서비스명(ai-dev, backend, frontend 등)> <환경(dev, prod)>" >&2
  exit 1
fi
RAW_SERVICE="$1" # backend, frontend, ai
ENV="$2"         # dev or prod

# [논리 서비스명 추출] (ai-dev → ai)
SERVICE=$(echo "$RAW_SERVICE" | cut -d'-' -f1)

# [Compose용 실제 서비스명/컴포즈 파일]
if [ "$SERVICE" = "ai" ]; then
  SERVICE_NAME="ai-${ENV}"
  COMPOSE_FILE="docker-compose.ai.yaml"
else
  SERVICE_NAME="$RAW_SERVICE"
  COMPOSE_FILE="docker-compose.${ENV}.yaml"
fi

# [경로 설정]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# [cloud 디렉토리에서 git pull로 최신화]
cd "$ROOT_DIR"
git pull
cd "$SCRIPT_DIR"

# [유틸 스크립트 불러오기]
source "$SCRIPT_DIR/utils.sh"

# [루트 디렉토리로 이동]
cd "$ROOT_DIR"

# [환경변수 로드]
echo "🔧 [$ENV] 환경변수 로드 중..."
if ! load_env "$SERVICE" "$ENV"; then
  echo "[startup.sh] 환경변수 로드 실패: $SERVICE $ENV" >&2
  exit 1
fi

# [이미지 경로 분기 처리]
if [ "$SERVICE" = "ai" ]; then
  PROJECT_ID="nemo-v2-ai-461016"
  IMAGE_FILE="asia-northeast3-docker.pkg.dev/${PROJECT_ID}/registry/${SERVICE}-${ENV}:${ENV}-latest"
else
  if [ "$ENV" = "prod" ]; then
    PROJECT_ID="nemo-v2-prod"
  else
    PROJECT_ID="nemo-v2"
  fi
  IMAGE_FILE="asia-northeast3-docker.pkg.dev/${PROJECT_ID}/registry/${SERVICE}:${ENV}-latest"
fi

# [기존 컨테이너 정리]
echo "🐳 도커 컴포즈로 기존 컨테이너 정지 및 제거 중..."
docker compose -f "$COMPOSE_FILE" stop "$SERVICE_NAME" || true
docker compose -f "$COMPOSE_FILE" rm -f "$SERVICE_NAME" || true

# [이미지 Pull]
echo "📥 강제 Pull: 최신 이미지 받아오는 중..."
docker pull "${IMAGE_FILE}"

# [컨테이너 재생성]
echo "🚀 컨테이너 재생성 중..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans "$SERVICE_NAME"

# [시작 알림]
notify_discord_cloud_only "☀️ [$ENV] $SERVICE 컨테이너 기동 완료!"
