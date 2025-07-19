#!/bin/bash

# ArgoCD Image Updater 설치 스크립트

set -e

echo "🚀 ArgoCD Image Updater 설치를 시작합니다..."

# Helm repository 추가
echo "📦 Helm repository 추가 중..."
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

# 네임스페이스 확인
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ argocd 네임스페이스가 존재하지 않습니다. ArgoCD를 먼저 설치해주세요."
    exit 1
fi

# 기존 설치 확인
if helm list -n argocd | grep -q argocd-image-updater; then
    echo "🔄 기존 ArgoCD Image Updater를 업그레이드합니다..."
    helm upgrade argocd-image-updater argo/argocd-image-updater \
        -n argocd \
        -f "$(dirname "$0")/values.yaml"
else
    echo "📥 ArgoCD Image Updater를 새로 설치합니다..."
    helm install argocd-image-updater argo/argocd-image-updater \
        -n argocd \
        -f "$(dirname "$0")/values.yaml"
fi

echo "⏳ Pod가 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-image-updater -n argocd --timeout=60s

echo "✅ ArgoCD Image Updater 설치가 완료되었습니다!"

echo "📊 설치 상태 확인:"
kubectl get pods -n argocd | grep image-updater

echo ""
echo "🔍 로그 확인 명령어:"
echo "kubectl logs -f deployment/argocd-image-updater -n argocd"

echo ""
echo "🧪 ECR 로그인 테스트 명령어:"
echo "kubectl exec -it deployment/argocd-image-updater -n argocd -- /scripts/ecr-login.sh"
