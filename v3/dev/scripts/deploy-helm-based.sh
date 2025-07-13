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

print_info() {
  echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_warning() {
  echo -e "${RED}⚠️  $1${NC}"
}

# 1단계: 기존 kubectl 리소스 정리
print_section "1. 기존 kubectl 리소스 정리"

print_step "기존 애플리케이션 리소스 정리"
kubectl delete namespace backend --ignore-not-found=true
kubectl delete namespace frontend --ignore-not-found=true
kubectl delete namespace mysql --ignore-not-found=true
kubectl delete namespace redis --ignore-not-found=true
print_success "기존 리소스 정리 완료"

# 2단계: ArgoCD Application 등록 (Helm 기반)
print_section "2. ArgoCD Application 등록 (Helm 기반)"

print_step "애플리케이션 Application 배포"
kubectl apply -f argocd/applications/
print_success "애플리케이션 Application 등록 완료"

print_info "애플리케이션 배포 순서: secrets → databases → backend → frontend"
print_info "ArgoCD가 Git 저장소를 감시하여 자동으로 Helm 차트를 배포합니다."

# 3단계: 배포 완료 대기
print_section "3. 배포 완료 대기"

print_step "애플리케이션 Application 상태 확인 (3분 대기)"
sleep 180

print_step "애플리케이션 Application 상태 재확인"
kubectl get applications -n argocd

# 4단계: Helm 차트 상태 확인
print_section "4. Helm 차트 상태 확인"

print_step "Helm 릴리스 목록 확인"
helm list --all-namespaces

print_step "모든 파드 상태 확인"
kubectl get pods --all-namespaces

# 5단계: 최종 상태 모니터링
print_section "5. 배포 상태 모니터링"

print_step "모든 Application 상태 확인"
kubectl get applications -n argocd

print_step "모든 파드 상태 확인"
kubectl get pods --all-namespaces

print_info "ArgoCD UI 접속 방법:"
print_info "kubectl port-forward svc/argocd-server -n argocd 8080:443"
print_info "브라우저에서 https://localhost:8080 접속"
print_info "초기 비밀번호: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

print_section "🎉 Helm 기반 GitOps 배포 완료!"
echo -e "${GREEN}모든 애플리케이션이 Helm 차트로 ArgoCD GitOps로 관리됩니다.${NC}"
echo -e "${YELLOW}Git 변경사항이 자동으로 감지되어 Helm 차트가 배포됩니다.${NC}"
echo -e "${BLUE}애플리케이션 변경: applications/ 디렉토리의 Helm 차트 수정 후 Git 푸시${NC}" 