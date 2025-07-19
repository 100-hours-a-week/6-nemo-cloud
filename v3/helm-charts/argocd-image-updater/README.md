# ArgoCD Image Updater 설치 가이드

ArgoCD Image Updater를 ECR과 함께 사용하기 위한 Helm 설치 가이드입니다.

## 전제 조건

1. **IRSA (IAM Roles for Service Accounts) 설정 완료**
   - EKS 클러스터에 OIDC provider 설정
   - `argocd-image-updater-irsa` IAM Role 생성 및 ECR 권한 부여

2. **ArgoCD 설치 완료**
   - ArgoCD가 `argocd` 네임스페이스에 설치되어 있어야 함

## 설치 방법

```bash
# Helm repository 추가
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# ArgoCD Image Updater 설치
helm install argocd-image-updater argo/argocd-image-updater \
  -n argocd \
  -f helm-charts/argocd-image-updater/values.yaml
```

## 업그레이드

```bash
helm upgrade argocd-image-updater argo/argocd-image-updater \
  -n argocd \
  -f helm-charts/argocd-image-updater/values.yaml
```

## 삭제

```bash
helm uninstall argocd-image-updater -n argocd
```

## 동작 확인

```bash
# Pod 상태 확인
kubectl get pods -n argocd | grep image-updater

# 로그 확인
kubectl logs -f deployment/argocd-image-updater -n argocd

# ECR 로그인 스크립트 테스트
kubectl exec -it deployment/argocd-image-updater -n argocd -- /scripts/ecr-login.sh
```

## 주요 설정

- **ECR 인증**: IRSA를 통한 자동 인증
- **Git 연동**: `infra/applications` 브랜치에 자동 커밋
- **이미지 업데이트 전략**: newest-build (latest 대신 사용 권장)
- **업데이트 주기**: 2분마다 ECR에서 새로운 이미지 확인

## 트러블슈팅

### ECR 인증 실패
```bash
# AWS 권한 확인
kubectl exec -it deployment/argocd-image-updater -n argocd -- aws sts get-caller-identity

# IRSA 토큰 확인
kubectl exec -it deployment/argocd-image-updater -n argocd -- cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

### Application 어노테이션 확인
애플리케이션에 다음 어노테이션이 있는지 확인:
```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: backend=084375578827.dkr.ecr.ap-northeast-2.amazonaws.com/backend
    argocd-image-updater.argoproj.io/update-strategy: newest-build
```
