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

# 유틸 불러오기
source "$SCRIPT_DIR/utils.sh"

# 루트 디렉토리 이동
cd "$ROOT_DIR"

# 환경변수 로드
echo "🔧 [$ENV] 환경변수 로드 중..."
load_env "$SERVICE" "$ENV"

# 기존 컨테이너 정리
echo "🐳 도커 컴포즈로 기존 컨테이너 정지 및 제거 중..."
docker compose -f "$COMPOSE_FILE" stop "$SERVICE_NAME" || true
docker compose -f "$COMPOSE_FILE" rm -f "$SERVICE_NAME" || true

# 이미지 Pull
echo "📥 강제 Pull: 최신 이미지 받아오는 중..."
docker pull "${IMAGE_FILE}"

# 컨테이너 재생성
echo "🚀 컨테이너 재생성 중..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans "$SERVICE_NAME"

# 시작 알림
notify_discord_cloud_only "☀️ [$ENV] $SERVICE 컨테이너 기동 완료!"
