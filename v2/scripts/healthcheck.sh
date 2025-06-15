#!/bin/bash
set -euo pipefail

SERVICE="$1"
ENV="$2"       # dev or prod

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/healthcheck_${SERVICE}.status"
GCP_PROJECT_ID_PROD=nemo-v2-prod

# 상태 파일 디렉토리 보장
sudo mkdir -p "$(dirname "$STATUS_FILE")"

source "$SCRIPT_DIR/utils.sh"

# dev = 서버 내 환경변수, prod = GCP Secret Manager
if [ "$ENV" == "dev" ]; then
  load_env "$SERVICE"
else
  echo "🔐 [prod] Secret Manager에서 환경변수 불러오는 중..."
  if SECRET_CONTENT=$(gcloud secrets versions access latest \
    --secret="${SERVICE}-${ENV}-env" \
    --project="${GCP_PROJECT_ID_PROD}"); then
    export $(echo "$SECRET_CONTENT" | xargs)
  else
    echo "❌ Secret Manager에서 환경변수 로딩 실패"
    exit 1
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🩺 [$SERVICE] 상태 확인 중..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MAX_RETRIES=20
RETRY_INTERVAL=10
STATUS=""

for ((i=1; i<=MAX_RETRIES; i++)); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTHCHECK_URL") || STATUS="000"

  if [[ "$STATUS" =~ ^2|3 ]]; then
    echo "✅ [$SERVICE] 정상 작동 (HTTP 200)"

    # 복구 감지
    if [ -f "$STATUS_FILE" ] && grep -q "unhealthy" "$STATUS_FILE"; then
      notify_discord_cloud_only "✅ [헬스체크 복구: $BRANCH] $SERVICE 서비스 복구 완료! (응답: HTTP 200)"
    fi

    echo "healthy" | sudo tee "$STATUS_FILE" > /dev/null
    exit 0
  else
    echo "⏳ [$SERVICE] 헬스체크 대기 중... ($i/$MAX_RETRIES) 응답: $STATUS"
    sleep "$RETRY_INTERVAL"
  fi
done

# 최종 실패 처리
if [[ "$STATUS" == "000" ]]; then
  STATUS_DESC="연결 실패 또는 타임아웃"
else
  STATUS_DESC="HTTP $STATUS"
fi

echo "❌ [$SERVICE] 서버 비정상 (응답: $STATUS_DESC)"

if [ ! -f "$STATUS_FILE" ] || grep -q "healthy" "$STATUS_FILE"; then
  notify_discord_cloud_only "❌ [헬스체크 실패: $BRANCH] $SERVICE 서비스 비정상 상태! (응답: $STATUS_DESC)"
fi

echo "unhealthy" | sudo tee "$STATUS_FILE" > /dev/null
exit 1
