#!/bin/bash
set -euo pipefail

ENV_FILE="$HOME/nemo/backend/.env"

# 환경변수 로드
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

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
