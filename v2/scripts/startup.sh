#!/bin/bash

echo "[INFO] Running startup script..."

SERVICE="$1"   # backend, frontend, ai
ENV="$2"       # dev or prod

cd /home/ubuntu/nemo/cloud/v2 || exit 1

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

echo "[INFO] Starting docker compose for $SERVICE..."
sudo /usr/bin/docker compose up -d "$SERVICE"ㄹ

echo "[INFO] Startup script completed."
