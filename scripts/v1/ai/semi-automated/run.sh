#!/bin/bash
set -euo pipefail

# 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

echo "🚀 PM2로 AI 서비스 실행 중..."
export PYTHONPATH=./src

pm2 start "$VENV_DIR/bin/uvicorn" \
  --name "$SERVICE_NAME" \
  --interpreter "$VENV_DIR/bin/python" \
  --cwd "$APP_DIR" \
  -- \
  src.main:app --host 0.0.0.0 --port "$PORT"

pm2 save