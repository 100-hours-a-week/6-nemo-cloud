#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-ai"
ROOT_DIR="$HOME/nemo/ai"
SCRIPT_DIR="$ROOT_DIR/scripts"
BACKUP_DIR="$ROOT_DIR/backups"
VENV_DIR="$ROOT_DIR/venv"
PORT=8000
ENV_FILE="$ROOT_DIR/.env"
TIMESTAMP=$(TZ=Asia/Seoul date +%Y%m%d-%H%M)
BRANCH="develop"

# 디스코드 웹훅
WEBHOOK_CLOUD_URL="https://discord.com/api/webhooks/1372113045471498250/al6sPD-f9AzhQiQslu3EjnsSq8iK1aEQJMT8vqLLEbGiPg2I53O_2Xx60PcxVTqmELio"
WEBHOOK_AI_URL="https://discord.com/api/webhooks/1372202362982240306/Q51_KNqRi1zIVGVU6WSkjlYMhd8KjOtOqwvNMIXIdmbuW_b-bG_Hf31vDBE1JaXPMZFk"

send_discord_notification() {
  local message="$1"
  for webhook_url in "$WEBHOOK_CLOUD_URL" "$WEBHOOK_AI_URL"
  do
    curl -H "Content-Type: application/json" \
      -X POST \
      -d "{\"content\": \"$message\"}" \
      "$webhook_url"
  done
}

# ===== 롤백 대상 결정 =====
if [ -n "${1:-}" ]; then
  TARGET_BACKUP="$BACKUP_DIR/$1"
  if [ ! -f "$TARGET_BACKUP" ]; then
    echo "❌ [$1] 해당 백업 파일이 존재하지 않습니다."
    exit 1
  fi
  echo "📦 지정 롤백: $TARGET_BACKUP"
else
  TARGET_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
  if [ -z "${TARGET_BACKUP:-}" ]; then
    echo "❌ 롤백 가능한 백업 파일이 존재하지 않습니다."
    exit 1
  fi
  echo "📦 최신 롤백: $TARGET_BACKUP"
fi

# 타임스탬프 추출
TARGET_FILE=$(basename "$TARGET_BACKUP")
ROLLBACK_POINT=$(echo "$TARGET_FILE" | grep -oP '\d{8}-\d{4}')

# 🛑 기존 서비스 종료
echo "🛑 기존 서비스 종료 중..."
pm2 delete "$SERVICE_NAME" || true

# 📦 소스 롤백
echo "📦 롤백 파일 적용 중..."
rm -rf "$ROOT_DIR/ai-service"
tar -xzf "$TARGET_BACKUP" -C "$ROOT_DIR"

# 📄 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

# 📦 패키지 설치
cd "$ROOT_DIR/ai-service"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# 🚀 PM2 재시작
echo "🚀 FastAPI 서비스 시작 중..."
pm2 start "$VENV_DIR/bin/uvicorn" \
  --name "$SERVICE_NAME" \
  --interpreter "$VENV_DIR/bin/python" \
  --cwd "$ROOT_DIR/ai-service" \
  -- src.main:app --host 0.0.0.0 --port "$PORT"
pm2 save

echo "✅ 롤백 완료: $TARGET_BACKUP"

# 🔎 헬스체크
echo "🔎 롤백 후 헬스체크 실행 중..."
sleep 7
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [롤백 성공: $BRANCH] $SERVICE_NAME 롤백 완료! (Rollback Point: $ROLLBACK_POINT)"
else
  send_discord_notification "❌ [롤백 실패: $BRANCH] $SERVICE_NAME 롤백 실패! (Rollback Point: $ROLLBACK_POINT)"
  exit 1
fi