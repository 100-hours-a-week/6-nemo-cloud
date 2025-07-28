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

# ArgoCD 설치 스크립트
print_section "ArgoCD 설치"

print_step "Helm 저장소 추가"
helm repo add argo-cd https://argoproj.github.io/argo-helm
if [ $? -eq 0 ]; then
  print_success "ArgoCD Helm 저장소 추가 완료"
else
  print_error "ArgoCD Helm 저장소 추가 실패"
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

print_step "ArgoCD 네임스페이스 생성"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
if [ $? -eq 0 ]; then
  print_success "ArgoCD 네임스페이스 생성 완료"
else
  print_error "ArgoCD 네임스페이스 생성 실패"
  exit 1
fi

print_step "ArgoCD 설치"
helm upgrade --install argocd argo-cd/argo-cd \
  --namespace argocd \
  --version 5.51.6 \
  --set server.extraArgs="{--insecure}" \
  --set server.ingress.enabled=true \
  --set server.ingress.hosts[0]=argocd.local \
  --wait --timeout 10m

if [ $? -eq 0 ]; then
  print_success "ArgoCD 설치 완료"
else
  print_error "ArgoCD 설치 실패"
  exit 1
fi

print_step "ArgoCD 상태 확인"
kubectl get pods -n argocd

print_step "ArgoCD 서비스 확인"
kubectl get svc -n argocd

print_info "ArgoCD UI 접속 방법:"
print_info "kubectl port-forward svc/argocd-server -n argocd 8080:443"
print_info "브라우저에서 https://localhost:8080 접속"
print_info "초기 비밀번호: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

print_section "🎉 ArgoCD 설치 완료!" 