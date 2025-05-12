## Backend Manual Deployment Guide (v1-dev)

### 1. 개요
본 문서는 개발 환경에서의 완전 수동(Bing Bang) 배포 방식을 설명합니다.
롤백 전략 없이, 모든 배포 과정을 명령어로 직접 수행하거나 배포 스크립트(deploy.sh)만 실행하며,
배포 완료 후 단순 헬스체크만 진행합니다.

### 2. 디렉토리 구조
```
~/backend-service/
├── build/
│   └── libs/
│       └── nemo-server-0.0.1-SNAPSHOT.jar
├── gradlew
├── gradlew.bat
├── .env           # (존재 시, 환경변수 파일)
└── deploy-backend.sh
# 스크립트 파일 위치 (홈 디렉토리 등, 관리 편한 곳에 저장)
~/deploy-backend.sh
```

### 3. 배포 절차 
1. DB 상태 확인
   - `systemctl status mysql  # 또는 sudo systemctl restart mysql`
2. Nginx 상태 확인
   - `systemctl status nginx  # 또는 sudo systemctl restart nginx`
3. 서버 접속
   - GCP 콘솔을 통해 SSH 접속
   - `sudo su - ubuntu` 명령어로 `ubuntu` 계정으로 전환하기
4. 배포 스크립트 준비
   - `deploy-backend.sh`로 저장 후 실행 권한 무여
   - `chmod +x deploy-backend.sh`
5. 배포 스크립트 수작업 입력 혹은 배포 스크립트 실행
   - `./deploy-backend`
6. 배포 후 로그 확인
   - `pm2 logs nemo-backend`

### 4. 배포 스크립트 내용
```bash
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
```


### 5. 비고
- 현 단계에서 .env 파일은 서버 내에서 관리
- [왜 서버에서 빌드?](https://github.com/100-hours-a-week/6-nemo-wiki/wiki/%5BCL%5D-%EC%84%9C%EB%B2%84%EC%97%90%EC%84%9C-%EB%B9%8C%EB%93%9C%ED%95%98%EB%8A%94-%EC%9D%B4%EC%9C%A0)
