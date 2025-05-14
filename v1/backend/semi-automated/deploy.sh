#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-backend"
ROOT_DIR="$HOME/nemo/backend"
REPO_URL="https://github.com/100-hours-a-week/6-nemo-be.git"
BRANCH="develop"
SCRIPT_DIR="$ROOT_DIR/scripts"

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

cd "$ROOT_DIR"

# 백업
bash "$SCRIPT_DIR/backup.sh"

# 소스 최신화
if [ -d "backend-service" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd backend-service
  if ! git pull origin "$BRANCH"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf backend-service
    git clone -b "$BRANCH" "$REPO_URL" backend-service
    cd backend-service
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "$BRANCH" "$REPO_URL" backend-service
  cd backend-service
fi

#PM2 프로세스 종료
pm2 delete "$SERVICE_NAME" || true

# 빌드
echo "⚙️ 백엔드 빌드 중..."
chmod +x gradlew
./gradlew clean bootJar -x test

# 🚀 실행
bash "$SCRIPT_DIR/run.sh"

# 🔎 헬스체크
sleep 30
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [배포 성공] $SERVICE_NAME 배포 완료! (브랜치: $BRANCH)"
else
  send_discord_notification "❌ [배포 실패] $SERVICE_NAME 배포 실패! (브랜치: $BRANCH)"
  exit 1
fi

# ✅ 완료
pm2 status
echo "✅ 백엔드 배포 완료!"