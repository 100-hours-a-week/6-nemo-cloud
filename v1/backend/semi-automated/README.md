### 1. 개요

- 기존의 명령어 기반의 수동 배포의 비효율성을 개선하고, 반복 작업은 스크립트로 자동화한 Semi-Automated 배포 방식
- 클라우드 담당자 뿐만 아니라 다른 파트 개발자도 서버에 동일하게 들어와 정해진 명령어(alias)만 실행해서 배포, 실행, 롤백, 헬스체크, 백업까지 모두 처리 가능

### 2. 서버 디렉토리 구조

```bash
~/nemo/
├── ai/
├── backend/
│   ├── backend-service/           # Git 소스 클론 위치
│   ├── jar-backups/               # JAR 파일 백업 저장소 (최대 7개 유지)
│   │   ├── 20250512-0037.jar      # [백업] 2025-05-12 00:37 생성
│   │   └── 20250512-0113.jar      # [백업] 2025-05-12 01:13 생성
│   ├── scripts/                   # 배포/운영 스크립트 모음
│   │   ├── backup.sh              # JAR 파일 백업 스크립트
│   │   ├── deploy.sh              # 전체 배포 스크립트 (백업 + 빌드 + 실행)
│   │   ├── healthcheck.sh         # 헬스체크 스크립트
│   │   ├── rollback.sh            # 롤백 스크립트
│   │   └── run.sh                 # PM2 서비스 실행 스크립트
│   └── .env                       #환경변수 파일
└── ...
```

### 3. 배포 / 운영 명령어 매핑

```bash
echo 'alias be-deploy="bash ~/nemo/backend/scripts/deploy.sh"' >> ~/.bashrc
echo 'be-rollback() { bash ~/nemo/backend/scripts/rollback.sh "$1"; }' >> ~/.bashrc
echo 'alias be-health="bash ~/nemo/backend/scripts/healthcheck.sh"' >> ~/.bashrc
echo 'alias be-run="bash ~/nemo/backend/scripts/run.sh"' >> ~/.bashrc
echo 'alias be-backup="bash ~/nemo/backend/scripts/backup.sh"' >> ~/.bashrc

source ~/.bashrc
```

| 명령어 | 설명 |
| --- | --- |
| `be-deploy` | 전체 배포 실행 |
| `be-rollback` | 최신 백업으로 롤백 |
| `be-rollback <timestamp>` | 특정 타임스탬프 롤백 (예: `be-rollback 20250512-0105`) |
| `be-health` | 헬스체크 수행 |
| `be-run` | PM2 서비스 재시작 |
| `be-backup` | JAR 수동 백업 실행 |

### 4. 주요 스크립트 설명

- `backup.sh` : JAR 파일 백업, 최대 7개 보관

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-backend"
    ROOT_DIR="$HOME/nemo/backend"
    BACKUP_DIR="$ROOT_DIR/jar-backups"
    JAR_PATH="backend-service/build/libs/nemo-server-0.0.1-SNAPSHOT.jar"
    TIMESTAMP=$(TZ=Asia/Seoul date +%Y%m%d-%H%M)  # 한국 시간 기준
    
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$ROOT_DIR/$JAR_PATH" ]; then
      echo "JAR 백업 중..."
      cp "$ROOT_DIR/$JAR_PATH" "$BACKUP_DIR/$TIMESTAMP.jar"
      
      # 최대 7개 유지
      ls -1t "$BACKUP_DIR" | tail -n +8 | xargs -I {} rm -f "$BACKUP_DIR/{}"
      echo "백업 완료: $BACKUP_DIR/$TIMESTAMP.jar"
    else
      echo "백업할 JAR 파일이 존재하지 않습니다: $ROOT_DIR/$JAR_PATH"
    fi
    ```

- `deploy.sh` : 전체 배포 프로세스 (백업 → 빌드 → 실행 → 헬스체크)

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-backend"
    ROOT_DIR="$HOME/nemo/backend"
    REPO_URL="https://github.com/100-hours-a-week/6-nemo-be.git"
    BRANCH="develop"
    SCRIPT_DIR="$ROOT_DIR/scripts"
    
    cd "$ROOT_DIR"
    
    # 백업
    bash "$SCRIPT_DIR/backup.sh"
    
    # 소스 최신화
    if [ -d "backend-service" ]; then
      echo "📦 기존 소스 업데이트 중..."
      cd backend-service
      if ! git pull origin "$BRANCH"; then
        echo "❌ git pull 실패. 클린 클론 시도..."
        cd ..
        rm -rf backend-service
        git clone -b "$BRANCH" "$REPO_URL" backend-service
        cd backend-service
      fi
    else
      echo "📥 소스 클론 중..."
      git clone -b "$BRANCH" "$REPO_URL" backend-service
      cd backend-service
    fi
    
    #PM2 프로세스 종료
    pm2 delete "$SERVICE_NAME" || true
    
    # 빌드
    echo "⚙️ 백엔드 빌드 중..."
    chmod +x gradlew
    ./gradlew clean bootJar -x test
    
    # 🚀 실행
    bash "$SCRIPT_DIR/run.sh"
    
    # 🔎 헬스체크
    sleep 30
    bash "$SCRIPT_DIR/healthcheck.sh"
    
    # ✅ 완료
    pm2 status
    echo "✅ 백엔드 배포 완료!"
    ```

- `run.sh` : PM2로 서버 실행 (환경변수 자동 로드)

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    SERVICE_NAME="nemo-backend"
    ROOT_DIR="$HOME/nemo/backend"
    PORT=8080
    JAR_FILE="$ROOT_DIR/backend-service/build/libs/nemo-server-0.0.1-SNAPSHOT.jar"
    ENV_FILE="$ROOT_DIR/.env"
    
    # 환경 변수 로드
    if [ -f "$ENV_FILE" ]; then
      echo "📄 .env 환경변수 로드 중..."
      set -a
      source "$ENV_FILE"
      set +a
    fi
    
    echo "🚀 PM2로 백엔드 서버 실행 중..."
    pm2 start "java -jar $JAR_FILE --server.port=$PORT" \
      --name "$SERVICE_NAME" \
      --cwd "$ROOT_DIR" \
    
    pm2 save
    ```

- `healthcheck.sh` : Spring Boot Actuator 헬스체크 수행

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    PORT=8080
    URL="http://localhost:$PORT/actuator/health"
    
    echo "🔎 헬스체크 요청 중..."
    
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    
    if [ "$STATUS" -eq 200 ]; then
      echo "✅ 백엔드 서버 정상 작동 (HTTP 200)"
      #exit 0
    else
      echo "❌ 백엔드 서버 비정상 (HTTP $STATUS)"
      #exit 1
    fi
    
    pm2 status
    ```

- `rollback.sh` : 최신/지정 JAR 파일로 롤백, 헬스체크 포함

    ```bash
    #!/bin/bash
    set -euo pipefail
    
    # ===== 기본 변수 =====
    SERVICE_NAME="nemo-backend"
    ROOT_DIR="$HOME/nemo/backend"
    SCRIPT_DIR="$ROOT_DIR/scripts"
    BACKUP_DIR="$ROOT_DIR/jar-backups"
    PORT=8080
    ENV_FILE="$ROOT_DIR/.env"
    
    # ===== 롤백 대상 결정 =====
    if [ -n "${1:-}" ]; then
      # 전체 파일명으로 롤백
      TARGET_JAR="$BACKUP_DIR/$1"
    
      if [ ! -f "$TARGET_JAR" ]; then
        echo "❌ [$1] 해당 백업 파일이 존재하지 않습니다."
        exit 1
      fi
      echo "📦 지정 롤백: $TARGET_JAR"
    else
      # 최신 백업으로 롤백
      TARGET_JAR=$(ls -t "$BACKUP_DIR"/*.jar 2>/dev/null | head -n 1)
    
      if [ -z "${TARGET_JAR:-}" ]; then
        echo "❌ 롤백 가능한 백업 파일이 존재하지 않습니다."
        exit 1
      fi
      echo "📦 최신 롤백: $TARGET_JAR"
    fi
    
    # ===== PM2 실행 =====
    echo "🛑 기존 서비스 종료 중..."
    pm2 delete "$SERVICE_NAME" || true
    
    # ===== 환경 변수 로드 =====
    if [ -f "$ENV_FILE" ]; then
      echo "📄 .env 환경변수 로드 중..."
      set -a
      source "$ENV_FILE"
      set +a
    fi
    
    echo "🚀 롤백 JAR 실행 중..."
    pm2 start "java -jar $TARGET_JAR --server.port=$PORT" --name "$SERVICE_NAME"
    pm2 save
    
    echo "✅ 롤백 완료: $TARGET_JAR"
    
    # ===== 헬스체크 =====
    echo "🔎 롤백 후 헬스체크 실행 중..."
    sleep 30
    bash "$SCRIPT_DIR/healthcheck.sh"
    ```


### 5. 비고