#!/bin/bash
set -e

echo "==== 프론트엔드(Next.js) 배포 시작 ===="
cd

# 1. 소스 최신화
if [ -d "6-nemo-fe" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd "6-nemo-fe"
  if ! git pull origin "dev"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf "6-nemo-fe"
    git clone -b "dev" "https://github.com/100-hours-a-week/6-nemo-fe.git"
    cd "6-nemo-fe"
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "dev" "https://github.com/100-hours-a-week/6-nemo-fe.git"
  cd "6-nemo-fe"
fi

# 2. 기존 PM2 프론트엔드 프로세스 종료
echo "🛑 기존 프론트엔드 PM2 프로세스 종료 중..."
pm2 delete nemo-frontend || true

# 3. pnpm 설치
echo "pnpm install 중..."
pnpm install

# 4. 환경변수 로드
if [ -f ".env" ]; then
  echo "📄 .env 환경변수 로드 중..."
	export $(grep -v '^#' .env | xargs || true)
fi

# 5. pnpm 빌드
echo "⚙️ pnpm build 중..."
pnpm run build

# 6. PM2로 실행
echo "PM2로 프론트 서버 실행 중..."
pm2 start pnpm --name nemo-frontend -- start

# 7. PM2 상태 저장 및 확인
pm2 save
pm2 status

# 8. 헬스 체크
echo "Next.js 서버 헬스체크 중..."
sleep 5
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000")

if [ "$RESPONSE" == "200" ]; then
  echo "✅ Next.js 서버 정상 동작 중 (HTTP 200)"
  echo "✅ FE 서비스 배포 완료"
  exit 0
else
  echo "❌ Next.js 서버 비정상 (응답 코드: $RESPONSE)"
  exit 1
fi