#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-ai"
ROOT_DIR="$HOME/nemo/ai"
REPO_URL="https://github.com/100-hours-a-week/6-nemo-ai.git"
BRANCH="develop"
SCRIPT_DIR="$ROOT_DIR/scripts"
VENV_DIR="$ROOT_DIR/venv"
PORT=8000

cd "$ROOT_DIR"

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

# 📦 백업
bash "$SCRIPT_DIR/backup.sh"

# 📥 소스 최신화
if [ -d "ai-service" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd ai-service
  if ! git pull origin "$BRANCH"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf ai-service
    git clone -b "$BRANCH" "$REPO_URL" ai-service
    cd ai-service
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "$BRANCH" "$REPO_URL" ai-service
  cd ai-service
fi

# 🛑 PM2 프로세스 종료
pm2 delete "$SERVICE_NAME" || true

# 🐍 가상환경 준비
echo "🐍 새 가상환경 생성 중..."
if [ ! -d "$VENV_DIR" ]; then
  echo "🐍 가상환경 생성 중..."
  python3.13 -m venv "$VENV_DIR"
fi

echo "📦 패키지 설치 중..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# 🚀 실행
bash "$SCRIPT_DIR/run.sh"

# 🔎 헬스체크
sleep 7
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [배포 성공: $BRANCH] $SERVICE_NAME 배포 완료!"
else
  send_discord_notification "❌ [배포 실패: $BRANCH] $SERVICE_NAME 배포 실패!"
  exit 1
fi

# ✅ 완료
pm2 status
echo "✅ AI 서비스 배포 완료!"