#!/bin/bash
set -euo pipefail

ENV_SOURCE_FILE="$HOME/nemo/frontend/.env"  # 복사할 환경변수 파일 경로

# 환경변수 로드
if [ -f "$ENV_SOURCE_FILE" ]; then
  set -a
  source "$ENV_SOURCE_FILE"
  set +a
fi

cd "$APP_DIR"

# 환경 변수 복사 및 로드
if [ -f "$ENV_SOURCE_FILE" ]; then
  cp "$ENV_SOURCE_FILE" "$ENV_FILE"
  echo "✅ .env 파일 복사 완료"
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE" || { echo "❌ .env 파일 로드 실패. 배포 중단."; exit 1; }
  set +a
else
  echo "❌ .env 파일이 $ENV_SOURCE_FILE 위치에 없습니다. 배포 중단."
  exit 1
fi

# 🚀 PM2로 프론트엔드 서비스 실행
echo "🚀 PM2로 프론트엔드 서비스 실행 중..."
pm2 delete "$SERVICE_NAME" || true
pm2 start "pnpm exec next start -p $PORT" \
  --name "$SERVICE_NAME" \
  --cwd "$APP_DIR"
pm2 save

pm2 status
