#!/bin/bash
set -euo pipefail

ENV_FILE="$HOME/nemo/ai/.env"

# 환경변수 로드
if [ -f "$ENV_FILE" ]; then
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