#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-backend"
HEALTH_URL="http://localhost:8080/actuator/health"
WEBHOOK_CLOUD_URL="https://discord.com/api/webhooks/1372113045471498250/al6sPD-f9AzhQiQslu3EjnsSq8iK1aEQJMT8vqLLEbGiPg2I53O_2Xx60PcxVTqmELio"

send_discord_alert() {
  local message="$1"
  curl -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"$message\"}" \
    "$WEBHOOK_CLOUD_URL"
}

RESPONSE=$(curl -s "$HEALTH_URL" || true)

if echo "$RESPONSE" | grep -q '"status":"UP"'; then
  echo "✅ [$SERVICE_NAME] 서비스 정상 동작 중."
else
  send_discord_alert "🚨 [헬스체크 실패] $SERVICE_NAME 비정상 상태 감지!"
fi