#!/bin/bash

set -euo pipefail

ENV_SOURCE_FILE="$HOME/nemo/frontend/.env"  # 복사할 환경변수 파일 경로

# 환경변수 로드
if [ -f "$ENV_SOURCE_FILE" ]; then
  set -a
  source "$ENV_SOURCE_FILE"
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

echo "🔎 [$SERVICE_NAME] 헬스체크 요청 중..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTHCHECK_URL")

# FE는 리디렉션하기 때문에 3.xx 포함
if [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 400 ]; then 
  echo "✅ [$SERVICE_NAME] 서버 정상 작동 (HTTP 200)"
else
  echo "❌ [$SERVICE_NAME] 서버 비정상 (HTTP $STATUS)"
  # send_discord_alert "🚨 [헬스체크 실패: $BRANCH] $SERVICE_NAME 비정상 상태 감지!"
  exit 1
fi

pm2 status
