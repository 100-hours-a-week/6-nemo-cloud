#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-ai"
HEALTH_URL="http://localhost:8000/"
WEBHOOK_CLOUD_URL="https://discord.com/api/webhooks/1372113045471498250/al6sPD-f9AzhQiQslu3EjnsSq8iK1aEQJMT8vqLLEbGiPg2I53O_2Xx60PcxVTqmELio"
BRANCH="develop"

send_discord_alert() {
  local message="$1"
  curl -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"$message\"}" \
    "$WEBHOOK_CLOUD_URL"
}

RESPONSE=$(curl -s "$HEALTH_URL" || true)

if echo "$RESPONSE" | grep -q '"message":"Hello World: Version 1 API is running"'; then
  echo "✅ [$SERVICE_NAME] 서비스 정상 동작 중."
else
  send_discord_alert "🚨 [헬스체크 실패: $BRANCH] $SERVICE_NAME 비정상 상태 감지!"
fi
