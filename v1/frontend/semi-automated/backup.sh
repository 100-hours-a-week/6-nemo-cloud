#!/bin/bash
set -euo pipefail

ENV_SOURCE_FILE="$HOME/nemo/frontend/.env"  # 복사할 환경변수 파일 경로

# 환경변수 로드
if [ -f "$ENV_SOURCE_FILE" ]; then
  set -a
  source "$ENV_SOURCE_FILE"
  set +a
fi

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
