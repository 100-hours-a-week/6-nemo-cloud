#!/bin/bash
set -euo pipefail

PORT=3000
URL="http://localhost:$PORT/"

echo "🔎 헬스체크 중..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L -X GET "$URL")

if [ "$RESPONSE" -eq 200 ]; then
  echo "✅ Next.js 서버 정상 작동 중 (HTTP 200)"
else
  echo "❌ Next.js 서버 비정상. 배포 확인 필요 (HTTP $RESPONSE)"
  exit 1
fi

echo "✅ 프론트엔드 서비스 헬스체크 완료"