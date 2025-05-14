#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-frontend"
APP_DIR="$HOME/nemo/frontend/frontend-service"
ENV_FILE="$APP_DIR/.env"

cd "$APP_DIR"

# 📄 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

# 🚀 PM2로 프론트엔드 서비스 실행
echo "🚀 PM2로 프론트엔드 서비스 실행 중..."
pm2 delete "$SERVICE_NAME" || true
pm2 start pnpm \
  --name "$SERVICE_NAME" \
  --cwd "$APP_DIR" \
  -- start

pm2 save
pm2 status
