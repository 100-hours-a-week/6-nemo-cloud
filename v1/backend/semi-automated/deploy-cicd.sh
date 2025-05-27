#!/bin/bash
set -euo pipefail
export PATH=$PATH:/home/ubuntu/.local/share/pnpm
export PATH=$PATH:/home/ubuntu/.local/share/pnpm:/home/ubuntu/.nvm/versions/node/v22.14.0/bin

ENV_FILE="$HOME/nemo/backend/.env"

# 환경변수 로드
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

cd "$ROOT_DIR"

# 백업
bash "$SCRIPT_DIR/backup.sh"

# PM2 프로세스 종료
pm2 delete "$SERVICE_NAME" || true

# 실행
bash "$SCRIPT_DIR/run.sh"

# 헬스체크
sleep 60
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [배포 성공: $BRANCH] $SERVICE_NAME 배포 완료!"
else
  send_discord_notification "❌ [배포 실패: $BRANCH] $SERVICE_NAME 배포 실패!"
  exit 1
fi

# 완료
pm2 status