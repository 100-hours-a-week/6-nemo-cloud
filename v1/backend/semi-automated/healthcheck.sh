#!/bin/bash
set -euo pipefail

ENV_FILE="$HOME/nemo/backend/.env"

# 환경변수 로드
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# 디스코드 알림
send_discord_alert() {
  local message="$1"
  curl -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"$message\"}" \
    "$WEBHOOK_CLOUD_URL"
}

echo "🔎 헬스체크 요청 중..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTHCHECK_URL")

if [ "$STATUS" -eq 200 ]; then
  echo "✅ [$SERVICE_NAME] 서버 정상 작동 (HTTP 200)"
else
  echo "❌ [$SERVICE_NAME] 서버 비정상 (HTTP $STATUS)"
  send_discord_alert "🚨 [헬스체크 실패: $BRANCH] $SERVICE_NAME 비정상 상태 감지!"
  exit 1
fi

pm2 status
