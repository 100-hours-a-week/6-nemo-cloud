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