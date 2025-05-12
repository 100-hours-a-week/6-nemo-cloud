#!/bin/bash
set -e

echo "==== 백엔드(Spring Boot) 배포 시작 ===="

# 1. 기존 소스 삭제
if [ -d "backend-service" ]; then
  echo "🧹 기존 backend-service 삭제 중..."
  rm -rf backend-service
fi

# 2. 소스 클론 및 브랜치 확인
echo "📥 백엔드 소스 클론 중..."
git clone -b develop https://github.com/100-hours-a-week/6-nemo-be
git pull origin develop

# 3. 기존 PM2 프로세스 종료
echo "🛑 기존 백엔드 PM2 프로세스 종료 중..."
pm2 delete nemo-backend || true

# 4. 빌드
echo "⚙️ 백엔드 빌드 중..."
chmod +x gradlew
./gradlew clean bootJar -x test

# 5. 환경변수 로드 (.env가 있다면)
if [ -f ".env" ]; then
  echo "📄 .env 환경변수 로드 중..."
  set -a
  source .env
  set +a
fi

# 6. PM2로 JAR 실행
echo "🚀 PM2로 백엔드 서버 실행 중..."
pm2 start "java -jar build/libs/nemo-server-0.0.1-SNAPSHOT.jar" \
  --name nemo-backend

# 7. PM2 상태 저장 및 확인
pm2 save
pm2 status

echo "✅ 백엔드 배포 완료"
curl http://localhost:8080/actuator/health
