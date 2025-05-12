# AI Manual Deployment Guide (v1-dev)

### 1. 개요

본 문서는 개발 환경에서의 **완전 수동(Bing Bang) 배포 방식**을 설명합니다.

롤백 전략 없이, 모든 배포 과정을 명령어로 직접 수행하거나 배포 스크립트(`deploy-ai.sh`)만 실행하며,

배포 완료 후 단순 헬스체크만 진행합니다.

### 2. 서버 디렉토리 구조

```
6-nemo-ai/
├── .github/              # GitHub Actions (옵션)
├── src/                  # FastAPI 소스코드
├── venv/                 # Python 가상환경 (로컬 배포용)
├── .env                  # (존재 시) 환경변수 파일
├── .gitignore            
├── README.md             
└── requirements.txt      # Python 패키지 의존성
```

### 3. 배포 절차

1. **서버 접속**
    - GCP 콘솔을 통해 SSH 접속
    - `sudo su - ubuntu` 명령어로 `ubuntu` 계정으로 전환하기
2. **배포 스크립트 준비 & 실행 권한 부여**
    - `deploy-ai.sh` 로 저장
    - `chmod +x deploy-ai.sh` 로 권한 부여
3. **배포 스크립트 수작업 입력 혹은 배포 스크립트 실행**
    - `./deploy-ai`
4. **배포 후 로그 확인**
    - `pm2 logs nemo-ai`

### 4. 배포 스크립트 내용

```bash
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
```

### 5. 비고

- 현 단계에서 .env 파일은 서버 내에서 관리
- API 테스트 예시:

    ```bash
    curl -X POST http://localhost:8000/ai/v1/groups/information \
      -H "Content-Type: application/json" \
      -d '{"name": "스터디 모임", "goal": "백엔드 개발 능력 향상", "category": "개발", "location": "판교", "period": "1개월 이하", "isPlanCreated": true}'
    ```