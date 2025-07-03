#!/bin/bash

# [공통] 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$ROOT_DIR/envs"

# [함수] 환경변수 로드 (GCP Secret Manager)
# $1: 서비스 이름 (frontend, backend, ai)
# $2: 환경 (dev, prod)
load_env() {
  local service="$1"
  local env="$2"
  if [ -z "$service" ] || [ -z "$env" ]; then
    echo "[load_env] 서비스명과 환경(dev/prod) 인자가 필요합니다." >&2
    return 1
  fi
  local env_file="$ENV_DIR/${service}.${env}.env"
  local secret_name="${service}-env-${env}"

  # GCP 프로젝트 ID 분기
  case "$service-$env" in
    ai-*) GCP_PROJECT_ID="nemo-v2-ai-461016" ;;
    *-dev) GCP_PROJECT_ID="nemo-v2" ;;
    *-prod) GCP_PROJECT_ID="nemo-v2-prod" ;;
    *)
      echo "[load_env] 알 수 없는 서비스/환경 조합: $service-$env" >&2
      return 1
      ;;
  esac

  echo "🔐 [$env] Secret Manager에서 [$secret_name] 로드 중..."
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "[load_env] gcloud 명령어가 설치되어 있지 않습니다." >&2
    return 1
  fi
  if SECRET_CONTENT=$(gcloud secrets versions access latest \
    --secret="$secret_name" \
    --project="${GCP_PROJECT_ID}" 2>/dev/null); then
    echo "📄 Secret 내용을 env 파일로 저장: $env_file"
    echo "$SECRET_CONTENT" >"$env_file"
    set -a
    source "$env_file"
    set +a
  else
    echo "❌ Secret Manager에서 환경변수 로딩 실패: $secret_name ($GCP_PROJECT_ID)" >&2
    return 1
  fi
}

# [함수] 디스코드 메시지 전송 (공통)
# $1: webhook_url, $2: message
send_discord() {
  local webhook_url="$1"
  local message="$2"
  if [ -z "$webhook_url" ]; then
    echo "[send_discord] Webhook URL이 비어 있습니다." >&2
    return 1
  fi
  if [ -z "$message" ]; then
    echo "[send_discord] 메시지가 비어 있습니다." >&2
    return 1
  fi
  curl -s -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"$message\"}" \
    "$webhook_url" >/dev/null || {
      echo "[send_discord] Discord 전송 실패: $webhook_url" >&2
      return 1
    }
}

# [함수] 클라우드 전용 알림
# $1: 메시지
notify_discord_cloud_only() {
  local message="$1"
  if [ -z "$WEBHOOK_CLOUD_URL" ]; then
    echo "[notify_discord_cloud_only] WEBHOOK_CLOUD_URL 환경변수가 비어 있습니다." >&2
    return 1
  fi
  send_discord "$WEBHOOK_CLOUD_URL" "$message"
}

# [함수] 클라우드 + 서비스별 알림
# $1: 서비스 이름, $2: 메시지
notify_discord_all() {
  local service="$1"
  local message="$2"
  if [ -z "$service" ] || [ -z "$message" ]; then
    echo "[notify_discord_all] 서비스명과 메시지 인자가 필요합니다." >&2
    return 1
  fi
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

  if [ "${#webhook_urls[@]}" -eq 0 ]; then
    echo "[notify_discord_all] 전송할 Webhook URL이 없습니다." >&2
    return 1
  fi

  for webhook_url in "${webhook_urls[@]}"; do
    send_discord "$webhook_url" "$message"
  done
}
