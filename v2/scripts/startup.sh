#!/bin/bash

echo "[INFO] Running startup script..."

SERVICE="$1"   # backend, frontend, ai
ENV=prod       # dev or prod

cd /home/ubuntu/nemo/cloud/v2 || exit 1

echo "[INFO] Pulling latest cloud repo..."
git pull origin develop || echo "[WARN] git pull 실패"

ENV_FILE="./envs/${SERVICE}.${ENV}.env"
SECRET_NAME="${SERVICE}-${ENV}-env"
PROJECT_ID="nemo-v2-prod"

echo "[INFO] Fetching env from Secret Manager for $SERVICE ($ENV)..."
if SECRET_CONTENT=$(gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID"); then
    echo "$SECRET_CONTENT" > "$ENV_FILE"
    echo "[INFO] Saved to $ENV_FILE"
else
    echo "[ERROR] Failed to fetch secret: $SECRET_NAME"
    exit 1
fi

echo "[INFO] Pulling latest docker images (all services)..."
docker compose -f docker-compose.prod.yaml pull

echo "[INFO] Starting docker compose (all services)..."
docker compose -f docker-compose.prod.yaml up -d --force-recreate

for TARGET_SERVICE in frontend backend; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🩺 [$TARGET_SERVICE] 헬스체크 수행"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if bash "$SCRIPT_DIR/healthcheck.sh" "$TARGET_SERVICE" "$ENV"; then
    notify_discord_all "✅ [배포 성공: $BRANCH] $TARGET_SERVICE 배포 완료!"
    echo "🎉 [$TARGET_SERVICE] 배포 완료"
  else
    notify_discord_all "❌ [배포 실패: $BRANCH] $TARGET_SERVICE 배포 실패!"
    exit 1
  fi
done

echo "[INFO] Startup script completed."
