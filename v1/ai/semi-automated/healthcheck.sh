#!/bin/bash
set -euo pipefail

PORT=8000
URL="http://localhost:$PORT/ai/v1/groups/information"

echo "🔎 헬스체크 및 API 테스트 중..."

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "스터디 모임",
        "goal": "백엔드 개발 능력 향상",
        "category": "개발",
        "location": "판교",
        "period": "1개월 이하",
        "isPlanCreated": true
      }')

if [ "$RESPONSE" -eq 200 ]; then
  echo "✅ FastAPI 서버 정상 작동 중 (HTTP 200)"
else
  echo "❌ FastAPI 서버 비정상. 배포 확인 필요 (HTTP $RESPONSE)"
  exit 1
fi

echo "✅ AI 서비스 배포 및 API 테스트 완료"