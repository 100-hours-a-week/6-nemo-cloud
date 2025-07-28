#!/bin/bash

set -e

cd /home/ubuntu/6-nemo-cloud/v3/dev

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_section() {
  echo -e "\n${BLUE}========== $1 ==========${NC}"
}

print_step() {
  echo -e "\n${YELLOW}📋 $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_info() {
  echo -e "${YELLOW}ℹ️  $1${NC}"
}

# cert-manager 설치 스크립트
print_section "cert-manager 설치"

print_step "Helm 저장소 추가"
helm repo add jetstack https://charts.jetstack.io
if [ $? -eq 0 ]; then
  print_success "cert-manager Helm 저장소 추가 완료"
else
  print_error "cert-manager Helm 저장소 추가 실패"
  exit 1
fi

print_step "Helm 저장소 업데이트"
helm repo update
if [ $? -eq 0 ]; then
  print_success "Helm 저장소 업데이트 완료"
else
  print_error "Helm 저장소 업데이트 실패"
  exit 1
fi

print_step "cert-manager 네임스페이스 생성"
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
if [ $? -eq 0 ]; then
  print_success "cert-manager 네임스페이스 생성 완료"
else
  print_error "cert-manager 네임스페이스 생성 실패"
  exit 1
fi

print_step "cert-manager 설치"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true \
  --version v1.14.2 \
  --wait --timeout 10m

if [ $? -eq 0 ]; then
  print_success "cert-manager 설치 완료"
else
  print_error "cert-manager 설치 실패"
  exit 1
fi

print_step "cert-manager 상태 확인"
kubectl get pods -n cert-manager

print_step "cert-manager CRD 확인"
kubectl get crd | grep cert-manager

print_info "cert-manager 설치 완료!"
print_info "ClusterIssuer를 생성하려면 bootstrap/cluster-issuer.yaml을 적용하세요:"
print_info "kubectl apply -f bootstrap/cluster-issuer.yaml"

print_section "🎉 cert-manager 설치 완료!" 