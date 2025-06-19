#!/bin/bash
set -euo pipefail

# 인자 설정
SERVICE="$1" # backend, frontend, ai
ENV="$2"     # dev or prod

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/envs/${SERVICE}.${ENV}.env"
COMPOSE_FILE="docker-compose.${ENV}.yaml"
IMAGE_FILE="asia-northeast3-docker.pkg.dev/nemo-v2/registry/${SERVICE}:${ENV}-latest"

# 유틸 불러오기
source "$SCRIPT_DIR/utils.sh"

# 루트로 이동
cd "$ROOT_DIR"

# 환경변수 로드
echo "🔧 [$ENV] 환경변수 로드 중..."
load_env "$SERVICE" "$ENV"

# 도커 컴포즈 실행
echo "🐳 도커 컴포즈로 실행 중..."
docker compose -f "$COMPOSE_FILE" stop "$SERVICE" || true
docker compose -f "$COMPOSE_FILE" rm -f "$SERVICE" || true

# 이미지 받아오기
echo "📥 강제 Pull: 최신 이미지 받아오는 중..."
docker pull "${IMAGE_FILE}"

# 컨테이너 재생성
echo "🚀 컨테이너 재생성 중..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans "$SERVICE"

# 헬스체크 수행
echo "🩺 헬스체크 수행 중..."
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
    notify_discord_all "$SERVICE" "✅ [배포 성공: $ENV] $SERVICE 배포 완료!"
else
    notify_discord_all "$SERVICE" "❌ [배포 실패: $ENV] $SERVICE 배포 실패!"
    exit 1
fi
