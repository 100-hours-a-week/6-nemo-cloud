#!/bin/bash
set -e

echo "==== 백엔드(Spring Boot) 배포 시작 ===="

# 1. 소스 최신화
if [ -d "6-nemo-be" ]; then
  echo "📦 기존 소스 업데이트 중..."
  cd "6-nemo-ai"
  if ! git pull origin "develop"; then
    echo "❌ git pull 실패. 클린 클론 시도..."
    cd ..
    rm -rf "6-nemo-ai"
    git clone -b "develop" "https://github.com/100-hours-a-week/6-nemo-be.git"
    cd "6-nemo-be"
  fi
else
  echo "📥 소스 클론 중..."
  git clone -b "develop" "https://github.com/100-hours-a-week/6-nemo-be.git"
  cd "6-nemo-be"
fi


# 2. 기존 PM2 프로세스 종료
echo "🛑 기존 백엔드 PM2 프로세스 종료 중..."
pm2 delete nemo-backend || true

# 3. 빌드
echo "⚙️ 백엔드 빌드 중..."
chmod +x gradlew
./gradlew clean bootJar -x test

# 4. 환경변수 로드 (.env가 있다면)
if [ -f ".env" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source .env
  set +a
fi

# 5. PM2로 JAR 실행
echo "🚀 PM2로 백엔드 서버 실행 중..."
pm2 start "java -jar build/libs/nemo-server-0.0.1-SNAPSHOT.jar" \\
  --name nemo-backend

# 6. PM2 상태 저장 및 확인
pm2 save
pm2 status

# 7. 헬스 체크
echo "🔎 [헬스체크] 백엔드 서비스 상태 확인 중..."
sleep 20
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health)
if [ "$STATUS" -eq 200 ]; then
  echo "✅ [헬스체크] 백엔드 서버 정상 작동 (HTTP $STATUS)"
else
  echo "❌ [헬스체크] 백엔드 서버 비정상 (HTTP $STATUS)"
  exit 1
fi

echo "✅ BE 서비스 배포 완료"