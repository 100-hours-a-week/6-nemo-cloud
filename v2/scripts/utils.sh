# 환경변수 로드 함수 / $1: 서비스 이름
load_env() {
  local SERVICE="$1"

  ENV_FILE="$HOME/nemo/cloud/v2/envs/${SERVICE}.env"

  if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
  else
    echo "❌ 환경변수 파일을 찾을 수 없습니다: $ENV_FILE"
    exit 1
  fi
}

# 클라우드 전용 알림 (헬스체크 실패)
notify_discord_cloud_only() {
  local message="$1"
  curl -s -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"$message\"}" \
       "$WEBHOOK_CLOUD_URL" > /dev/null
}

# 클라우드 + 서비스 알림 (배포/롤백 결과)
notify_discord_all() {
  local message="$1"
  local webhook_urls=()

  # 클라우드 웹훅 항상 포함
  if [ -n "${WEBHOOK_CLOUD_URL:-}" ]; then
    webhook_urls+=("$WEBHOOK_CLOUD_URL")
  fi

  # 서비스 웹훅 동적 추출 (WEBHOOK_BACKEND_URL 등)
  local upper_service
  upper_service=$(echo "$SERVICE" | tr '[:lower:]' '[:upper:]')
  local service_webhook_var="WEBHOOK_${upper_service}_URL"
  local service_webhook="${!service_webhook_var:-}"

  if [ -n "$service_webhook" ]; then
    webhook_urls+=("$service_webhook")
  fi

  for webhook_url in "${webhook_urls[@]}"; do
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$webhook_url" > /dev/null
  done
}
