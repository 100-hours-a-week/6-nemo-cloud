#!/bin/bash
set -euo pipefail

ENV_SOURCE_FILE="$HOME/nemo/frontend/.env"  # 복사할 환경변수 파일 경로

# 환경변수 로드
if [ -f "$ENV_SOURCE_FILE" ]; then
  set -a
  source "$ENV_SOURCE_FILE"
  set +a
fi

# 디스코드 웹훅
send_discord_notification() {
  local message="$1"

  for webhook_url in "$WEBHOOK_CLOUD_URL" "$WEBHOOK_FRONTEND_URL"
  do
    curl -H "Content-Type: application/json" \
      -X POST \
      -d "{\"content\": \"$message\"}" \
      "$webhook_url"
  done
}

# 롤백 대상 결정
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

# 타임스탬프 추출
TARGET_FILE=$(basename "$TARGET_BACKUP")
ROLLBACK_POINT=$(echo "$TARGET_FILE" | grep -oP '\d{8}-\d{4}')

# 빌드 산출물 롤백
echo "📦 롤백 파일 적용 중..."
rm -rf "$APP_DIR/.next"
mkdir -p "$APP_DIR/.next"
tar -xzf "$TARGET_BACKUP" -C "$APP_DIR/.next"

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

# 기존 서비스 종료
echo "🛑 PM2 기존 프로세스 종료 중..."
pm2 delete "$SERVICE_NAME" || true

# 실행
echo "🚀 PM2로 프론트엔드 서비스 재시작 중..."
pm2 start "pnpm exec next start -p $PORT" \
  --name "$SERVICE_NAME" \
  --cwd "$APP_DIR"
pm2 save

echo "✅ 롤백 완료: $TARGET_BACKUP"

# 🔎 헬스체크
echo "🔎 롤백 후 헬스체크 실행 중..."
sleep 10
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [롤백 성공: $BRANCH] $SERVICE_NAME 롤백 완료! (Rollback Point: $ROLLBACK_POINT)"
else
  send_discord_notification "❌ [롤백 실패: $BRANCH] $SERVICE_NAME 롤백 실패! (Rollback Point: $ROLLBACK_POINT)"
  exit 1
fi

pm2 status
