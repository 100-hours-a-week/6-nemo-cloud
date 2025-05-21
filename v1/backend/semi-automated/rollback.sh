#!/bin/bash
set -euo pipefail

# ===== 기본 변수 =====
SERVICE_NAME="nemo-backend"
ROOT_DIR="$HOME/nemo/backend"
SCRIPT_DIR="$ROOT_DIR/scripts"
BACKUP_DIR="$ROOT_DIR/jar-backups"
PORT=8080
ENV_FILE="$ROOT_DIR/.env"
BRANCH="develop"

# 디스코드 웹훅
WEBHOOK_CLOUD_URL="https://discord.com/api/webhooks/1372113045471498250/al6sPD-f9AzhQiQslu3EjnsSq8iK1aEQJMT8vqLLEbGiPg2I53O_2Xx60PcxVTqmELio"
WEBHOOK_BACKEND_URL="https://discord.com/api/webhooks/1372140999526055946/TrJvSiBpJzR5ufVpqYLatHQlcwzCqCxd0mWg2aWM2quwpKPN1SU0VeZLM3Z_nrKSujub"

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

# ===== 롤백 대상 결정 =====
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

# ===== PM2 실행 =====
echo "🛑 기존 서비스 종료 중..."
pm2 delete "$SERVICE_NAME" || true

# ===== 환경 변수 로드 =====
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

echo "🚀 롤백 JAR 실행 중..."
pm2 start "java -jar $TARGET_JAR --server.port=$PORT" --name "$SERVICE_NAME"
pm2 save

echo "✅ 롤백 완료: $TARGET_JAR"

# ===== 헬스체크 =====
echo "🔎 롤백 후 헬스체크 실행 중..."
sleep 30
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [롤백 성공: $BRANCH] $SERVICE_NAME 롤백 완료! (Rollback Point: $TIMESTAMP)"
else
  send_discord_notification "❌ [롤백 실패: $BRANCH] $SERVICE_NAME 롤백 실패! (Rollback Point: $TIMESTAMP)"
  exit 1
fi
