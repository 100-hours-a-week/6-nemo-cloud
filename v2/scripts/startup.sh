#!/bin/bash
set -euo pipefail

# 인자 설정
RAW_SERVICE="$1" # backend, frontend, ai
ENV="$2"         # dev or prod
SERVICE=$(echo "$RAW_SERVICE" | cut -d'-' -f1)

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# AI 분리 로직
if [ "$SERVICE" = "ai" ]; then
  COMPOSE_FILE="docker-compose.ai.yaml"
  SERVICE_NAME="ai-${ENV}"
else
  COMPOSE_FILE="docker-compose.${ENV}.yaml"
  SERVICE_NAME="$RAW_SERVICE"
fi

ENV_FILE="$ROOT_DIR/envs/${SERVICE}.${ENV}.env"

# 유틸 불러오기
source "$SCRIPT_DIR/utils.sh"

# 환경변수 직접 로드
echo "🔧 [$ENV] 환경변수 로드 중..."
if [ -f "$ENV_FILE" ]; then
  echo "📄 로컬 .env 파일 로드: $ENV_FILE"
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "❌ .env 파일이 존재하지 않음: $ENV_FILE"
  exit 1
fi

# 도커 컴포즈 실행
cd "$ROOT_DIR"
echo "🐳 도커 컴포즈로 실행 중..."
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE" || true

# 시작 알림
notify_discord_cloud_only "☀️ [$ENV] $SERVICE 컨테이너 기동 완료!"
