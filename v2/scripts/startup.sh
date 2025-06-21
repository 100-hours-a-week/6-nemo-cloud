#!/bin/bash
set -euo pipefail

# 인자 설정
SERVICE="$1" # backend, frontend, ai
ENV="$2"     # dev or prod

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="docker-compose.${ENV}.yaml"

# 유틸 불러오기
source "$SCRIPT_DIR/utils.sh"

# 루트로 이동
cd "$ROOT_DIR"

# 환경변수 로드
echo "🔧 [$ENV] 환경변수 로드 중..."
load_env "$SERVICE" "$ENV"

# 도커 컴포즈 실행
echo "🐳 도커 컴포즈로 실행 중..."
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE" || true

# 헬스체크 후 시작 알림
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
  notify_discord_cloud_only "☀️ [서버 시작: $ENV] $SERVICE 서버 시작!"
else
  notify_discord_cloud_only "❌ [헬스체크 실패: $ENV] $SERVICE 서비스 비정상 상태! (응답: $STATUS_DESC)"
  exit 1
fi
