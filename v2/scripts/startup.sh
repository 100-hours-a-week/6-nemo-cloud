#!/bin/bash

echo "[INFO] Running startup script..."

SERVICE="$1"   # backend, frontend, ai
ENV=prod       # dev or prod

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd /home/ubuntu/nemo/cloud/v2 || exit 1

echo "[INFO] Pulling latest cloud repo..."
git pull origin develop || echo "[WARN] git pull 실패"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ID="nemo-v2-prod"
SECRET_NAME="${SERVICE}-${ENV}-env"
ENV_FILE="./envs/${SERVICE}.${ENV}.env"

echo "[INFO] Fetching env from Secret Manager for $SERVICE ($ENV)..."
if SECRET_CONTENT=$(gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID"); then
    echo "$SECRET_CONTENT" > "$ENV_FILE"
    echo "[INFO] Saved to $ENV_FILE"
else
    echo "❌ Failed to fetch secret: $SECRET_NAME"
    exit 1
fi

echo "[INFO] Pulling latest docker image for $SERVICE..."
docker compose -f docker-compose.prod.yaml pull "$SERVICE"

echo "[INFO] Starting docker container for $SERVICE..."
docker compose -f docker-compose.prod.yaml up -d --force-recreate "$SERVICE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🩺 [$SERVICE] 헬스체크 수행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if bash "$SCRIPT_DIR/healthcheck.sh" "$SERVICE" "$ENV"; then
  notify_discord_all "✅ [배포 성공: $BRANCH] $SERVICE 배포 완료!"
  echo "🎉 [$SERVICE] 배포 완료"
else
  notify_discord_all "❌ [배포 실패: $BRANCH] $SERVICE 배포 실패!"
  exit 1
fi

echo "[INFO] Startup script completed."