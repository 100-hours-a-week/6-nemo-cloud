#!/bin/bash
set -euo pipefail

# [인자 체크] 서비스명/환경 필수
if [ $# -lt 2 ]; then
  echo "[healthcheck.sh] 사용법: $0 <서비스명(ai-dev, backend 등)> <환경(dev, prod)>" >&2
  exit 1
fi
RAW_SERVICE="$1"
ENV="$2"
SERVICE=$(echo "$RAW_SERVICE" | cut -d'-' -f1)

# [경로 설정]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/healthcheck_${SERVICE}.status"

# [상수]
MAX_RETRIES=20
RETRY_INTERVAL=15
STATUS=""

# [상태 파일 디렉토리 보장]
sudo mkdir -p "$(dirname "$STATUS_FILE")"

# [유틸 불러오기]
source "$SCRIPT_DIR/utils.sh"

# [환경변수 로드]
echo "🔧 [$ENV] 환경변수 로드 중..."
if ! load_env "$SERVICE" "$ENV"; then
  echo "[healthcheck.sh] 환경변수 로드 실패: $SERVICE $ENV" >&2
  exit 1
fi

# [HEALTHCHECK_URL 체크]
if [ -z "${HEALTHCHECK_URL:-}" ]; then
  echo "[healthcheck.sh] HEALTHCHECK_URL 환경변수가 비어 있습니다." >&2
  exit 1
fi

# [헬스 체크]
echo "🩺 [$SERVICE] 상태 확인 중..."
for ((i = 1; i <= MAX_RETRIES; i++)); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTHCHECK_URL") || STATUS="000"

  if [[ "$STATUS" =~ ^2|3 ]]; then
    echo "✅ [$SERVICE] 정상 작동 (HTTP $STATUS)"
    # 복구 감지
    if [ -f "$STATUS_FILE" ] && grep -q "unhealthy" "$STATUS_FILE"; then
      notify_discord_cloud_only "✅ [헬스체크 복구: $ENV] $SERVICE 서비스 복구 완료! (응답: HTTP $STATUS)"
    fi
    echo "healthy" | sudo tee "$STATUS_FILE" >/dev/null
    exit 0
  else
    echo "⏳ [$SERVICE] 헬스체크 대기 중... ($i/$MAX_RETRIES) 응답: $STATUS"
    sleep "$RETRY_INTERVAL"
  fi
done

# [최종 실패 처리]
if [[ "$STATUS" == "000" ]]; then
  STATUS_DESC="연결 실패 또는 타임아웃"
else
  STATUS_DESC="HTTP $STATUS"
fi

echo "❌ [$ENV] $SERVICE 서버 비정상 (응답: $STATUS_DESC)"
if [ ! -f "$STATUS_FILE" ] || grep -q "healthy" "$STATUS_FILE"; then
  notify_discord_cloud_only "❌ [헬스체크 실패: $ENV] $SERVICE 서비스 비정상 상태! (응답: $STATUS_DESC)"
fi
echo "unhealthy" | sudo tee "$STATUS_FILE" >/dev/null
exit 1
