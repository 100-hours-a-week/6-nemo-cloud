#!/bin/bash
set -euo pipefail

# 인자 설정
RAW_SERVICE="$1"
ENV="$2"
SERVICE=$(echo "$RAW_SERVICE" | cut -d'-' -f1)

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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

# 종료 알림
notify_discord_cloud_only "🌙 [$ENV] $SERVICE 컨테이너 종료!"
