#!/bin/bash
set -euo pipefail
export PATH=$PATH:/home/ubuntu/.local/share/pnpm
export PATH=$PATH:/home/ubuntu/.local/share/pnpm:/home/ubuntu/.nvm/versions/node/v22.14.0/bin

ENV_FILE="$HOME/nemo/ai/.env"

# 환경변수 로드
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# 디스코드 웹훅
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

cd "$ROOT_DIR"

# 백업
bash "$SCRIPT_DIR/backup.sh"

# 소스 코드 및 배포 스크립트 최신화
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

# PM2 프로세스 종료
pm2 delete "$SERVICE_NAME" || true

# 가상환경 준비
echo "🐍 새 가상환경 생성 중..."
if [ ! -d "$VENV_DIR" ]; then
  echo "🐍 가상환경 생성 중..."
  python3.13 -m venv "$VENV_DIR"
fi

# 패키지 설치
echo "📦 패키지 설치 중..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# 실행
bash "$SCRIPT_DIR/run.sh"

# 헬스체크 후 알림 여부 결정
sleep 5
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [배포 성공: $BRANCH] $SERVICE_NAME 배포 완료!"
else
  send_discord_notification "❌ [배포 실패: $BRANCH] $SERVICE_NAME 배포 실패!"
  exit 1
fi

# 완료
pm2 status
