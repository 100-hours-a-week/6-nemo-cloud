#!/bin/bash
set -euo pipefail

SERVICE_NAME="nemo-frontend"
ROOT_DIR="$HOME/nemo/frontend"
REPO_URL="https://github.com/100-hours-a-week/6-nemo-fe.git"
BRANCH="dev"
SCRIPT_DIR="$ROOT_DIR/scripts"
APP_DIR="$ROOT_DIR/frontend-service"
ENV_FILE="$APP_DIR/.env"
PORT=3000

cd "$ROOT_DIR"

# 📦 [1/6] 빌드 산출물 백업
bash "$SCRIPT_DIR/backup.sh"

# 📥 [2/6] 소스 최신화
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

# 📄 [3/6] 환경 변수 로드
if [ -f "$ENV_FILE" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source "$ENV_FILE"
  set +a
fi

# 📦 [4/6] 패키지 설치 & 빌드
echo "📦 패키지 설치 중..."
pnpm install

echo "⚙️ 빌드 중..."
pnpm run build

# 🚀 [5/6] PM2로 서비스 실행 (빌드 후 실행만 run.sh에서 담당)
bash "$SCRIPT_DIR/run.sh"

# 🔎 [6/6] 헬스체크
sleep 7
bash "$SCRIPT_DIR/healthcheck.sh"

# ✅ 완료
pm2 status
echo "✅ 프론트엔드 서비스 배포 완료!"