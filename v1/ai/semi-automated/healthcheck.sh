#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-ai"
PORT=8000
URL="http://localhost:$PORT/"

echo "🔎 [$SERVICE_NAME] 헬스체크 요청 중..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$STATUS" -eq 200 ]; then
  echo "✅ [$SERVICE_NAME] 서버 정상 작동 (HTTP 200)"
else
  echo "❌ [$SERVICE_NAME] 서버 비정상 (HTTP $STATUS)"
  exit 1
fi

pm2 status
