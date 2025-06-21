#!/bin/bash
set -euo pipefail

# 인자 설정
SERVICE="$1" # backend, frontend, ai
ENV="$2"     # dev or prod

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 유틸 불러오기
source "$SCRIPT_DIR/utils.sh"

# 루트로 이동
cd "$ROOT_DIR"

# 환경변수 로드
echo "🔧 [$ENV] 환경변수 로드 중..."
load_env "$SERVICE" "$ENV"

# 종료 알림
notify_discord_cloud_only "🌙 [서버 종료: $ENV] $SERVICE 서버 종료!"
