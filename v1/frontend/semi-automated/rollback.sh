#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-frontend"
ROOT_DIR="$HOME/nemo/frontend"
SCRIPT_DIR="$ROOT_DIR/scripts"
BACKUP_DIR="$ROOT_DIR/.next-backups"
APP_DIR="$ROOT_DIR/frontend-service"
ENV_FILE="$APP_DIR/.env"
PORT=3000

# 📦 롤백 대상 결정
if [ -n "${1:-}" ]; then
  TARGET_BACKUP="$BACKUP_DIR/$1"
  if [ ! -f "$TARGET_BACKUP" ]; then
    echo "❌ [$1] 해당 백업 파일이 존재하지 않습니다."
    exit 1
  fi
  echo "📦 지정된 백업 파일로 롤백: $TARGET_BACKUP"
else
  TARGET_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
  if [ -z "${TARGET_BACKUP:-}" ]; then
    echo "❌ 롤백 가능한 백업 파일이 존재하지 않습니다."
    exit 1
  fi
  echo "📦 최신 백업 파일로 롤백: $TARGET_BACKUP"
fi

# 🛑 기존 서비스 종료
echo "🛑 PM2 기존 프로세스 종료 중..."
pm2 delete "$SERVICE_NAME" || true

# 📂 빌드 산출물 롤백
echo "📦 롤백 파일 적용 중..."
rm -rf "$APP_DIR/.next"
mkdir -p "$APP_DIR/.next"
tar -xzf "$TARGET_BACKUP" -C "$APP_DIR/.next"

# 📄 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

# 🚀 PM2로 서비스 재시작
echo "🚀 PM2로 프론트엔드 서비스 재시작 중..."
pm2 start pnpm \
  --name "$SERVICE_NAME" \
  --cwd "$APP_DIR" \
  -- start
pm2 save

echo "✅ 롤백 완료: $TARGET_BACKUP"

# 🔎 헬스체크
echo "🔎 롤백 후 헬스체크 실행 중..."
sleep 7
bash "$SCRIPT_DIR/healthcheck.sh"