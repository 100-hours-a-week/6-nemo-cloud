#!/bin/bash
set -euo pipefail

ENV_FILE="$HOME/nemo/backend/.env"

# 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# 디스코드 웹훅
send_discord_notification() {
  local message="$1"
  
  for webhook_url in "$WEBHOOK_CLOUD_URL" "$WEBHOOK_BACKEND_URL"
  do
    curl -H "Content-Type: application/json" \
      -X POST \
      -d "{\"content\": \"$message\"}" \
      "$webhook_url"
  done
}

# 롤백 대상 결정
if [ -n "${1:-}" ]; then
  # 전체 파일명으로 롤백
  TARGET_JAR="$BACKUP_DIR/$1"
  if [ ! -f "$TARGET_JAR" ]; then
    echo "❌ [$1] 해당 백업 파일이 존재하지 않습니다."
    exit 1
  fi
  echo "📦 지정 롤백: $TARGET_JAR"
else
  # 최신 백업으로 롤백
  TARGET_JAR=$(ls -t "$BACKUP_DIR"/*.jar 2>/dev/null | head -n 1)
  if [ -z "${TARGET_JAR:-}" ]; then
    echo "❌ 롤백 가능한 백업 파일이 존재하지 않습니다."
    exit 1
  fi
  echo "📦 최신 롤백: $TARGET_JAR"
fi

# 타임스탬프 추출
TARGET_FILE=$(basename "$TARGET_JAR")
TIMESTAMP=$(echo "$TARGET_FILE" | grep -oP '\d{8}-\d{4}')

# 기존 서비스 종료
echo "🛑 기존 서비스 종료 중..."
pm2 delete "$SERVICE_NAME" || true

# PM2 실행
echo "🚀 롤백 JAR 실행 중..."
pm2 start "java -jar $TARGET_JAR --server.port=$PORT" --name "$SERVICE_NAME"
pm2 save

echo "✅ 롤백 완료: $TARGET_JAR"

# 헬스체크
echo "🔎 롤백 후 헬스체크 실행 중..."
sleep 30
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [롤백 성공: $BRANCH] $SERVICE_NAME 롤백 완료! (Rollback Point: $TIMESTAMP)"
else
  send_discord_notification "❌ [롤백 실패: $BRANCH] $SERVICE_NAME 롤백 실패! (Rollback Point: $TIMESTAMP)"
  exit 1
fi
