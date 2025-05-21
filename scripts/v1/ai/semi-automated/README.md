# AI Semi-Automated Deployment Guide (v1-dev)

### 1. 개요

- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능

### 2. 서버 디렉토리 구조

```bash
~/nemo/
└── ai/
    ├── ai-service/                # Git 소스 클론 위치 (프로젝트 루트)
    │   ├── src/
		│   │   ├── key.json     
    │   ├── venv/                 
    │   └── requirements.txt      
    ├── scripts/                  
    │   ├── backup.sh            
    │   ├── deploy.sh             
    │   ├── healthcheck.sh        
    │   ├── rollback.sh           
    │   └── run.sh                
    ├── .env                       # 환경변수 파일          
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias ai-deploy="bash ~/nemo/ai/scripts/deploy.sh"' >> ~/.bashrc
echo 'ai-rollback() { bash ~/nemo/ai/scripts/rollback.sh "$1"; }' >> ~/.bashrc
echo 'alias ai-health="bash ~/nemo/ai/scripts/healthcheck.sh"' >> ~/.bashrc
echo 'alias ai-run="bash ~/nemo/ai/scripts/run.sh"' >> ~/.bashrc
echo 'alias ai-backup="bash ~/nemo/ai/scripts/backup.sh"' >> ~/.bashrc

source ~/.bashrc
```

| 명령어 | 설명 |
| --- | --- |
| `ai-deploy` | AI 전체 배포 |
| `ai-rollback` | 최신 롤백 |
| `ai-rollback <파일명>` | 특정 백업 롤백 |
| `ai-health` | 헬스체크 수행 |
| `ai-run` | AI 서버 재시작 (PM2) |
| `ai-backup` | AI 소스 백업 |

### 4. 주요 스크립트 설명

- `backup.sh` : JAR 파일 백업, 최대 7개 보관

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-ai"
    ROOT_DIR="$HOME/nemo/ai"
    BACKUP_DIR="$ROOT_DIR/backups"
    TIMESTAMP=$(TZ=Asia/Seoul date +%Y%m%d-%H%M)
    
    mkdir -p "$BACKUP_DIR"
    
    # FastAPI 소스 백업 (필요 시 모델 파일 등도 포함 가능)
    if [ -d "$ROOT_DIR/ai-service" ]; then
      echo "📦 AI 서비스 소스 백업 중..."
      tar -czf "$BACKUP_DIR/$TIMESTAMP.tar.gz" -C "$ROOT_DIR" ai-service
      
      # 최대 7개만 유지
      ls -1t "$BACKUP_DIR" | tail -n +8 | xargs -I {} rm -f "$BACKUP_DIR/{}"
      
      echo "✅ 백업 완료: $BACKUP_DIR/$TIMESTAMP.tar.gz"
    else
      echo "❌ 백업할 소스 디렉토리가 존재하지 않습니다: $ROOT_DIR/ai-service"
    fi
    ```

- `deploy.sh` : 전체 배포 프로세스 (백업 → 빌드 → 실행 → 헬스체크)

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-ai"
    ROOT_DIR="$HOME/nemo/ai"
    REPO_URL="https://github.com/100-hours-a-week/6-nemo-ai.git"
    BRANCH="develop"
    SCRIPT_DIR="$ROOT_DIR/scripts"
    VENV_DIR="$ROOT_DIR/venv"
    PORT=8000
    
    cd "$ROOT_DIR"
    
    # 📦 백업
    bash "$SCRIPT_DIR/backup.sh"
    
    # 📥 소스 최신화
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
    
    # 🛑 PM2 프로세스 종료
    pm2 delete "$SERVICE_NAME" || true
    
    # 🐍 가상환경 준비
    if [ -d "$VENV_DIR" ]; then
      echo "🐍 기존 가상환경 삭제 중..."
      rm -rf "$VENV_DIR"
    fi
    
    echo "🐍 새 가상환경 생성 중..."
    python3.13 -m venv "$VENV_DIR"
    
    echo "📦 패키지 설치 중..."
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    
    # 🚀 실행
    bash "$SCRIPT_DIR/run.sh"
    
    # 🔎 헬스체크
    sleep 7
    bash "$SCRIPT_DIR/healthcheck.sh"
    
    # ✅ 완료
    pm2 status
    echo "✅ AI 서비스 배포 완료!"
    ```

- `run.sh` : PM2로 서버 실행 (환경변수 자동 로드)

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-ai"
    ROOT_DIR="$HOME/nemo/ai"
    VENV_DIR="$ROOT_DIR/venv"
    PORT=8000
    APP_DIR="$ROOT_DIR/ai-service"
    ENV_FILE="$ROOT_DIR/.env"
    
    # 환경 변수 로드
    if [ -f "$ENV_FILE" ]; then
      echo "📄 .env 환경변수 로드 중..."
      set -a
      source "$ENV_FILE"
      set +a
    fi
    
    echo "🚀 PM2로 AI 서비스 실행 중..."
    export PYTHONPATH=./src
    
    pm2 start "$VENV_DIR/bin/uvicorn" \
      --name "$SERVICE_NAME" \
      --interpreter "$VENV_DIR/bin/python" \
      --cwd "$APP_DIR" \
      -- \
      src.main:app --host 0.0.0.0 --port "$PORT"
    
    pm2 save
    ```

- `healthcheck.sh` : Spring Boot Actuator 헬스체크 수행

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    PORT=8000
    URL="http://localhost:$PORT/ai/v1/groups/information"
    
    echo "🔎 헬스체크 및 API 테스트 중..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL" \
      -H "Content-Type: application/json" \
      -d '{
            "name": "스터디 모임",
            "goal": "백엔드 개발 능력 향상",
            "category": "개발",
            "location": "판교",
            "period": "1개월 이하",
            "isPlanCreated": true
          }')
    
    if [ "$RESPONSE" -eq 200 ]; then
      echo "✅ FastAPI 서버 정상 작동 중 (HTTP 200)"
    else
      echo "❌ FastAPI 서버 비정상. 배포 확인 필요 (HTTP $RESPONSE)"
      exit 1
    fi
    
    echo "✅ AI 서비스 배포 및 API 테스트 완료"
    ```

- `rollback.sh` : 최신/지정 JAR 파일로 롤백, 헬스체크 포함

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-ai"
    ROOT_DIR="$HOME/nemo/ai"
    SCRIPT_DIR="$ROOT_DIR/scripts"
    BACKUP_DIR="$ROOT_DIR/backups"
    VENV_DIR="$ROOT_DIR/venv"
    PORT=8000
    ENV_FILE="$ROOT_DIR/.env"
    
    # 롤백 대상 결정
    if [ -n "${1:-}" ]; then
      TARGET_BACKUP="$BACKUP_DIR/$1"
      if [ ! -f "$TARGET_BACKUP" ]; then
        echo "❌ [$1] 해당 백업 파일이 존재하지 않습니다."
        exit 1
      fi
      echo "📦 지정 롤백: $TARGET_BACKUP"
    else
      TARGET_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
      if [ -z "${TARGET_BACKUP:-}" ]; then
        echo "❌ 롤백 가능한 백업 파일이 존재하지 않습니다."
        exit 1
      fi
      echo "📦 최신 롤백: $TARGET_BACKUP"
    fi
    
    # 기존 서비스 종료
    echo "🛑 기존 서비스 종료 중..."
    pm2 delete "$SERVICE_NAME" || true
    
    # 소스 롤백
    echo "📦 롤백 파일 적용 중..."
    rm -rf "$ROOT_DIR/ai-service"
    tar -xzf "$TARGET_BACKUP" -C "$ROOT_DIR"
    
    # 환경 변수 로드
    if [ -f "$ENV_FILE" ]; then
      echo "📄 .env 환경변수 로드 중..."
      set -a
      source "$ENV_FILE"
      set +a
    fi
    
    # 패키지 설치
    cd "$ROOT_DIR/ai-service"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    
    # PM2 재시작
    echo "🚀 롤백 JAR 실행 중..."
    pm2 start "$VENV_DIR/bin/uvicorn" \
      --name "$SERVICE_NAME" \
      --interpreter "$VENV_DIR/bin/python" \
      --cwd "$ROOT_DIR/ai-service" \
      -- src.main:app --host 0.0.0.0 --port "$PORT"
    pm2 save
    
    echo "✅ 롤백 완료: $TARGET_BACKUP"
    
    # 헬스체크
    echo "🔎 롤백 후 헬스체크 실행 중..."
    bash "$SCRIPT_DIR/healthcheck.sh"
    
    ```


### 5. 비고

- 기존의 Manual 방식은 없던 롤백 로직 추가
- [Python 환경 버전 불일치 트러블 슈팅]( https://github.com/100-hours-a-week/6-nemo-wiki/issues/121)