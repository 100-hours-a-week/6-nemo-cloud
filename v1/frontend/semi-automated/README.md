# Frontend  Semi-Automated Deployment Guide (v1-dev)

### 1. 개요

- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능

### 2. 서버 디렉토리 구조

```bash
~/nemo/
└── frontend/
    ├── .env                      # 프론트엔드 환경 변수 파일 (루트에서 관리)
    ├── frontend-service/                # Git 소스 클론 위치
    ├── .next-backups/            # 빌드 산출물 백업 저장소 (최대 7개 유지)
    │   ├── .next-20250513-1030/  # [백업] 2025-05-13 10:30 생성
    └── scripts/                  # 배포/운영 자동화 스크립트
        ├── backup.sh
        ├── deploy.sh
        ├── healthcheck.sh
        ├── rollback.sh
        └── run.sh
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias fe-deploy="bash ~/nemo/frontend/scripts/deploy.sh"' >> ~/.bashrc
echo 'fe-rollback() { bash ~/nemo/frontend/scripts/rollback.sh "$1"; }' >> ~/.bashrc
echo 'alias fe-health="bash ~/nemo/frontend/scripts/healthcheck.sh"' >> ~/.bashrc
echo 'alias fe-run="bash ~/nemo/frontend/scripts/run.sh"' >> ~/.bashrc
echo 'alias fe-backup="bash ~/nemo/frontend/scripts/backup.sh"' >> ~/.bashrc

# 적용
source ~/.bashrc
```

| 명령어 | 설명 |
| --- | --- |
| `fe-deploy` | 프론트엔드 전체 배포 |
| `fe-rollback` | 프론트엔드 최신 롤백 |
| `fe-rollback <파일명>` | 프론트엔드 특정 백업 롤백 |
| `fe-health` | 프론트엔드 헬스체크 수행 |
| `fe-run` | 프론트엔드 서버 재시작 (PM2) |
| `fe-backup` | 프론트엔드 빌드 산출물 백업 |

### 4. 주요 스크립트 설명

- **`deploy.sh`**

    ```bash
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
    ```

- **`backup.sh`**

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-frontend"
    ROOT_DIR="$HOME/nemo/frontend"
    BACKUP_DIR="$ROOT_DIR/.next-backups"
    SOURCE_DIR="$ROOT_DIR/frontend-service/.next"
    TIMESTAMP=$(TZ=Asia/Seoul date +%Y%m%d-%H%M)
    
    mkdir -p "$BACKUP_DIR"
    
    # .next 빌드 산출물 백업
    if [ -d "$SOURCE_DIR" ]; then
      echo "📦 프론트엔드 빌드 산출물 백업 중..."
      tar -czf "$BACKUP_DIR/$TIMESTAMP.tar.gz" -C "$SOURCE_DIR" .
    
      # 최대 7개만 유지
      ls -1t "$BACKUP_DIR" | tail -n +8 | xargs -I {} rm -f "$BACKUP_DIR/{}"
    
      echo "✅ 백업 완료: $BACKUP_DIR/$TIMESTAMP.tar.gz"
    else
      echo "❌ 백업할 빌드 산출물이 존재하지 않습니다: $SOURCE_DIR"
    fi
    ```

- **`run.sh`**

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-frontend"
    APP_DIR="$HOME/nemo/frontend/frontend-service"
    ENV_FILE="$APP_DIR/.env"
    
    cd "$APP_DIR"
    
    # 📄 환경 변수 로드
    if [ -f "$ENV_FILE" ]; then
      echo "📄 .env 환경변수 로드 중..."
      set -a
      source "$ENV_FILE"
      set +a
    fi
    
    # 🚀 PM2로 프론트엔드 서비스 실행
    echo "🚀 PM2로 프론트엔드 서비스 실행 중..."
    pm2 delete "$SERVICE_NAME" || true
    pm2 start pnpm \
      --name "$SERVICE_NAME" \
      --cwd "$APP_DIR" \
      -- start
    
    pm2 save
    pm2 status
    ```

- **`healthcheck.sh`**

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    PORT=3000
    URL="http://localhost:$PORT/"
    
    echo "🔎 헬스체크 중..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L -X GET "$URL")
    
    if [ "$RESPONSE" -eq 200 ]; then
      echo "✅ Next.js 서버 정상 작동 중 (HTTP 200)"
    else
      echo "❌ Next.js 서버 비정상. 배포 확인 필요 (HTTP $RESPONSE)"
      exit 1
    fi
    
    echo "✅ 프론트엔드 서비스 헬스체크 완료"
    ```

- **`rollback.sh`**

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-frontend"
    ROOT_DIR="$HOME/nemo/frontend"
    SCRIPT_DIR="$ROOT_DIR/scripts"
    BACKUP_DIR="$ROOT_DIR/.next-backups"
    APP_DIR="$ROOT_DIR/frontend-service"
    ENV_FILE="$APP_DIR/.env"
    PORT=3000
    
    # 📦 롤백 대상 결정
    if [ -n "${1:-}" ]; then
      TARGET_BACKUP="$BACKUP_DIR/$1"
      if [ ! -f "$TARGET_BACKUP" ]; then
        echo "❌ [$1] 해당 백업 파일이 존재하지 않습니다."
        exit 1
      fi
      echo "📦 지정된 백업 파일로 롤백: $TARGET_BACKUP"
    else
      TARGET_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
      if [ -z "${TARGET_BACKUP:-}" ]; then
        echo "❌ 롤백 가능한 백업 파일이 존재하지 않습니다."
        exit 1
      fi
      echo "📦 최신 백업 파일로 롤백: $TARGET_BACKUP"
    fi
    
    # 🛑 기존 서비스 종료
    echo "🛑 PM2 기존 프로세스 종료 중..."
    pm2 delete "$SERVICE_NAME" || true
    
    # 📂 빌드 산출물 롤백
    echo "📦 롤백 파일 적용 중..."
    rm -rf "$APP_DIR/.next"
    mkdir -p "$APP_DIR/.next"
    tar -xzf "$TARGET_BACKUP" -C "$APP_DIR/.next"
    
    # 📄 환경 변수 로드
    if [ -f "$ENV_FILE" ]; then
      echo "📄 .env 환경변수 로드 중..."
      set -a
      source "$ENV_FILE"
      set +a
    fi
    
    # 🚀 PM2로 서비스 재시작
    echo "🚀 PM2로 프론트엔드 서비스 재시작 중..."
    pm2 start pnpm \
      --name "$SERVICE_NAME" \
      --cwd "$APP_DIR" \
      -- start
    pm2 save
    
    echo "✅ 롤백 완료: $TARGET_BACKUP"
    
    # 🔎 헬스체크
    echo "🔎 롤백 후 헬스체크 실행 중..."
    sleep 7
    bash "$SCRIPT_DIR/healthcheck.sh"
    ```


### 5. 비고

- .env 파일 관리 필요
- ESLint Config 파일 관리 필요
- 초기엔 권한 필요: `chmod +x ~/nemo/frontend/scripts/*.sh`