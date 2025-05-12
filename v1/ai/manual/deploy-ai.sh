#!/bin/bash
set -e

echo "==== AI 서비스(FastAPI) 배포 시작 ===="

# 1. 소스 최신화
if [ -d "6-nemo-ai" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd "6-nemo-ai"
  if ! git pull origin "develop"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf "6-nemo-ai"
    git clone -b "develop" "https://github.com/100-hours-a-week/6-nemo-ai.git"
    cd "6-nemo-ai"
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "develop" "https://github.com/100-hours-a-week/6-nemo-ai.git"
  cd "6-nemo-ai"
fi

# 2. 기존 PM2 프로세스 정리
echo "기존 ai PM2 프로세스 종료 중..."
pm2 delete nemo-ai || true

# 3. Python 가상환경 생성
echo "Python 가상환경 생성 중..."
python3 -m venv venv

# 4. 가상환경 활성화 및 의존성 설치
echo "가상환경 활성화 및 패키지 설치 중..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 5. PM2로 FastAPI 서버 실행
echo "PM2로 FastAPI 서버 실행 중..."
export PYTHONPATH=./src
pm2 start venv/bin/uvicorn \
  --name nemo-ai \
  --interpreter ./venv/bin/python \
  -- src.main:app --host 0.0.0.0 --port 8000

# 6. PM2 상태 저장 및 확인
pm2 save
pm2 status

# 7. 가상환경 비활성화 및 헬스체크
deactivate
sleep 10
echo "🔎 [헬스체크] AI 서비스 상태 확인 중..."
RESPONSE=$(curl -s http://localhost:8000)
EXPECTED_MESSAGE="Hello World: Version 1 API is running"

if [[ "$RESPONSE" == *"$EXPECTED_MESSAGE"* ]]; then
  echo "✅ [헬스체크] AI 서버 정상 작동 (메시지 확인 완료)"
else
  echo "❌ [헬스체크] AI 서버 비정상 (메시지 미일치)"
  exit 1
fi

echo "✅ AI 서비스 배포 완료"