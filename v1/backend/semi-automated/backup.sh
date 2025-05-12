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