#!/bin/bash
set -euo pipefail

ENV_FILE="$HOME/nemo/backend/.env"

# 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

echo "🚀 PM2로 백엔드 서버 실행 중..."

# 서울 타입 
pm2 start java --name "$SERVICE_NAME" -- \
  -Duser.timezone=Asia/Seoul \
  -jar "$JAR_FILE" \
  --server.port=$PORT

pm2 save