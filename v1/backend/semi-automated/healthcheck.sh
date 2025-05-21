#!/bin/bash

set -euo pipefail

PORT=8080
URL="http://localhost:$PORT/actuator/health"

echo "🔎 헬스체크 요청 중..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$STATUS" -eq 200 ]; then
  echo "✅ 백엔드 서버 정상 작동 (HTTP 200)"
  exit 0
else
  echo "❌ 백엔드 서버 비정상 (HTTP $STATUS)"
  exit 1
fi

pm2 status
