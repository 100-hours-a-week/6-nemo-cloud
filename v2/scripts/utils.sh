#!/bin/bash

# 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$ROOT_DIR/envs"

# 환경변수 로드 함수
# $1: 서비스 이름 (frontend, backend, ai)
# $2: 환경 (dev, prod)
load_env() {
  local service="$1"
  local env="$2"
  local env_file="$ENV_DIR/${service}.${env}.env"
  local secret_name="${service}-env-${env}" # ex: backend-env-dev

  # 하드코딩된 GCP 프로젝트 ID 분기
  if [ "$env" = "dev" ]; then
    GCP_PROJECT_ID="nemo-v2"
  elif [ "$env" = "prod" ]; then
    GCP_PROJECT_ID="nemo-v2-prod"
  elif [ "$service" = "ai" ]; then
    GCP_PROJECT_ID="nemo-v2-ai-461016"
  else
    echo "❌ 지원하지 않는 환경입니다: $env"
    exit 1
  fi

  echo "🔐 [$env] Secret Manager에서 [$secret_name] 로드 중..."
  if SECRET_CONTENT=$(gcloud secrets versions access latest \
    --secret="$secret_name" \
    --project="${GCP_PROJECT_ID}"); then

    echo "📄 Secret 내용을 env 파일로 저장: $env_file"
    echo "$SECRET_CONTENT" >"$env_file"

    set -a
    source "$env_file"
    set +a

  else
    echo "❌ Secret Manager에서 환경변수 로딩 실패"
    exit 1
  fi
}

# 공통 디스코드 전송 함수
send_discord() {
  local webhook_url="$1"
  local message="$2"
  curl -s -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"$message\"}" \
    "$webhook_url" >/dev/null
}

# 클라우드 전용 알림
# $1: 메시지
notify_discord_cloud_only() {
  local message="$1"
  send_discord "$WEBHOOK_CLOUD_URL" "$message"
}

# 클라우드 + 서비스 알림
# $1: 서비스 이름, $2: 메시지
notify_discord_all() {
  local service="$1"
  local message="$2"
  local webhook_urls=()

  # 클라우드 채널
  if [ -n "${WEBHOOK_CLOUD_URL:-}" ]; then
    webhook_urls+=("$WEBHOOK_CLOUD_URL")
  fi

  # 서비스별 채널 (예: WEBHOOK_BACKEND_URL)
  local upper_service
  upper_service=$(echo "$service" | tr '[:lower:]' '[:upper:]')
  local service_webhook_var="WEBHOOK_${upper_service}_URL"
  local service_webhook="${!service_webhook_var:-}"

  if [ -n "$service_webhook" ]; then
    webhook_urls+=("$service_webhook")
  fi

  for webhook_url in "${webhook_urls[@]}"; do
    send_discord "$webhook_url" "$message"
  done
}
