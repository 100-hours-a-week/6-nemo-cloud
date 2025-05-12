# Backend Manual Deployment Guide (v1-dev)

### 1. 개요

본 문서는 개발 환경에서의 **완전 수동(Bing Bang) 배포 방식**을 설명합니다.

롤백 전략 없이, 모든 배포 과정을 명령어로 직접 수행하거나 배포 스크립트(`deploy-backend.sh`)만 실행하며,

배포 완료 후 단순 헬스체크만 진행합니다.

### 2. 서버 디렉토리 구조

```
6-nemo-be/
├── .github/                  # GitHub Actions (옵션)
├── .gradle/                  
├── build/                    # JAR 빌드 결과물 (배포용 JAR 위치)
├── deploy-backend.sh                   # 배포 스크립트 위치 (추가 가능)
├── gradle/                   
├── src/                      # Spring Boot 소스코드
├── .env                      # (존재 시) 환경변수 파일
├── .gitattributes
├── .gitignore
├── build.gradle.kts          # Gradle 빌드 스크립트
├── gradlew
├── gradlew.bat
└── settings.gradle.kts
```

### 3. 배포 절차

1. **DB 상태 확인**
   - `systemctl status mysql # 또는 sudo systemctl restart mysql`
2. **Nginx 상태 확인**
   - `systemctl status nginx # 또는 sudo systemctl restart nginx`
3. **서버 접속**
   - GCP 콘솔을 통해 SSH 접속
   - `sudo su - ubuntu` 명령어로 `ubuntu` 계정으로 전환하기
4. **배포 스크립트 준비**
   - `deploy-backend.sh`로 저장 후 실행 권한 무여
   - `chmod +x deploy-backend.sh`
5. **배포 스크립트 수작업 입력 혹은 배포 스크립트 실행**
   - `./deploy-backend`
6. **배포 후 로그 확인**
   - `pm2 logs nemo-backend`

### 4. 배포 스크립트 내용

```bash
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
```

### 5. 비고

- 현 단계에서 .env 파일은 서버 내에서 관리
- [왜 서버에서 빌드?](https://github.com/100-hours-a-week/6-nemo-wiki/wiki/%5BCL%5D-%EC%84%9C%EB%B2%84%EC%97%90%EC%84%9C-%EB%B9%8C%EB%93%9C%ED%95%98%EB%8A%94-%EC%9D%B4%EC%9C%A0)