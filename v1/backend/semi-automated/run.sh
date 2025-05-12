#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-backend"
ROOT_DIR="$HOME/nemo/backend"
PORT=8080
JAR_FILE="$ROOT_DIR/backend-service/build/libs/nemo-server-0.0.1-SNAPSHOT.jar"
ENV_FILE="$ROOT_DIR/.env"

# 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

echo "🚀 PM2로 백엔드 서버 실행 중..."
pm2 start "java -jar $JAR_FILE --server.port=$PORT" \
  --name "$SERVICE_NAME" \
  --cwd "$ROOT_DIR" \

pm2 save