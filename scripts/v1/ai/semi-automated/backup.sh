#!/bin/bash
set -euo pipefail

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
