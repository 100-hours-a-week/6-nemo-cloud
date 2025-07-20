#!/bin/bash
set -euo pipefail

echo "🔍 Backend 서비스 ClusterIP 조회 중..."

# Backend 서비스의 ClusterIP 가져오기
BACKEND_IP=$(kubectl get service backend -n backend -o jsonpath='{.spec.clusterIP}')

if [ -z "$BACKEND_IP" ]; then
  echo "❌ Backend 서비스 IP를 찾을 수 없습니다."
  exit 1
fi

echo "✅ Backend 서비스 IP: $BACKEND_IP"

# 현재 frontend의 backend-proxy Endpoints IP 확인
CURRENT_IP=$(kubectl get endpoints backend-proxy -n frontend -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "none")

if [ "$CURRENT_IP" = "$BACKEND_IP" ]; then
  echo "📍 IP가 이미 최신입니다. 업데이트 불필요."
  exit 0
fi

echo "🔄 backend-proxy Endpoints 업데이트 중... ($CURRENT_IP → $BACKEND_IP)"

# Frontend 네임스페이스의 backend-proxy Endpoints 업데이트
kubectl patch endpoints backend-proxy -n frontend --type='merge' -p="{
  \"subsets\": [
    {
      \"addresses\": [
        {
          \"ip\": \"$BACKEND_IP\"
        }
      ],
      \"ports\": [
        {
          \"name\": \"http\",
          \"port\": 8080,
          \"protocol\": \"TCP\"
        }
      ]
    }
  ]
}"

echo "✅ backend-proxy Endpoints 업데이트 완료!"

# Helm template에서도 IP 업데이트
TEMPLATE_FILE="v3/helm-charts/frontend/templates/backend-proxy-service.yaml"
if [ -f "$TEMPLATE_FILE" ]; then
  echo "🔧 Helm template 파일 업데이트 중..."
  sed -i.bak "s/ip: \"[0-9.]*\"/ip: \"$BACKEND_IP\"/" "$TEMPLATE_FILE"
  echo "✅ Helm template 업데이트 완료!"
fi

echo ""
echo "📊 현재 상태 확인:"
echo "Backend 서비스 IP: $BACKEND_IP"
kubectl get endpoints backend-proxy -n frontend -o jsonpath='Proxy Endpoints IP: {.subsets[0].addresses[0].ip}' && echo ""

echo ""
echo "🎯 연결 테스트 진행 중..."
kubectl exec -n frontend deployment/frontend -- wget -T 5 -O- "http://backend-proxy:8080/actuator/health" 2>/dev/null && echo "✅ 연결 성공!" || echo "❌ 연결 실패"
