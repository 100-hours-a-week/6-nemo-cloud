#!/bin/bash
set -euo pipefail
export PATH=$PATH:/home/ubuntu/.local/share/pnpm
export PATH=$PATH:/home/ubuntu/.local/share/pnpm:/home/ubuntu/.nvm/versions/node/v22.14.0/bin

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

cd "$ROOT_DIR"

# 백업
bash "$SCRIPT_DIR/backup.sh"

# 소스 최신화
if [ -d "frontend-service" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd frontend-service
  if ! git pull origin "$BRANCH"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf frontend-service
    git clone -b "$BRANCH" "$REPO_URL" frontend-service
    cd frontend-service
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "$BRANCH" "$REPO_URL" frontend-service
  cd frontend-service
fi

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

# 패키지 설치
echo "📦 패키지 설치 중..."
pnpm install

# 빌드
echo "⚙️ 빌드 중..."
pnpm run build

# 실행
bash "$SCRIPT_DIR/run.sh"

# 헬스체크 후 알림 여부 결정
sleep 10
if bash "$SCRIPT_DIR/healthcheck.sh"; then
  send_discord_notification "✅ [배포 성공: $BRANCH] $SERVICE_NAME 배포 완료!"
else
  send_discord_notification "❌ [배포 실패: $BRANCH] $SERVICE_NAME 배포 실패!"
  exit 1
fi
