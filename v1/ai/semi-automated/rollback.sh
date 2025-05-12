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
