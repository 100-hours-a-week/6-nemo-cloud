#!/bin/bash
set -euo pipefail

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
