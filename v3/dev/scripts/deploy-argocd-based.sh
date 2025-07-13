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

# 1단계: ArgoCD 설치 (GitOps 도구)
print_section "1. ArgoCD 설치 (GitOps 도구)"

print_step "ArgoCD 네임스페이스 생성"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
print_success "ArgoCD 네임스페이스 생성 완료"

print_step "ArgoCD 설치"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
print_success "ArgoCD 설치 완료"

print_step "ArgoCD 준비 대기 (60초)"
echo "ArgoCD 파드들이 시작되는 동안 대기합니다..."
sleep 60

print_step "ArgoCD 상태 확인"
kubectl get pods -n argocd
print_success "ArgoCD 상태 확인 완료"

# 2단계: 인프라 Application 등록 (GitOps)
print_section "2. 인프라 Application 등록 (GitOps)"

print_step "인프라 Application 배포"
kubectl apply -f argocd/infrastructure/
print_success "인프라 Application 등록 완료"

print_info "인프라 배포 순서: StorageClass → Bootstrap → cert-manager → Ingress → ArgoCD 설정"
print_info "ArgoCD가 Git 저장소를 감시하여 자동으로 인프라를 배포합니다."

# 3단계: 인프라 배포 완료 대기
print_section "3. 인프라 배포 완료 대기"

print_step "인프라 Application 상태 확인 (2분 대기)"
sleep 120

print_step "인프라 Application 상태 재확인"
kubectl get applications -n argocd
kubectl get pods --all-namespaces | grep -E "(cert-manager|ingress-nginx|argocd)"

# 4단계: 애플리케이션 Application 등록 (GitOps)
print_section "4. 애플리케이션 Application 등록 (GitOps)"

print_step "애플리케이션 Application 배포"
kubectl apply -f argocd/applications/
print_success "애플리케이션 Application 등록 완료"

print_info "애플리케이션 배포 순서: secrets → databases → backend → frontend"
print_info "ArgoCD가 Git 저장소를 감시하여 자동으로 애플리케이션을 배포합니다."

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

print_section "🎉 완전 GitOps 배포 완료!"
echo -e "${GREEN}모든 인프라와 애플리케이션이 ArgoCD GitOps로 관리됩니다.${NC}"
echo -e "${YELLOW}Git 변경사항이 자동으로 감지되어 배포됩니다.${NC}"
echo -e "${BLUE}인프라 변경: infrastructure/ 디렉토리 수정 후 Git 푸시${NC}"
echo -e "${BLUE}애플리케이션 변경: applications/ 디렉토리 수정 후 Git 푸시${NC}" 