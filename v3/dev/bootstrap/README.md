# Bootstrap 리소스 및 초기화 가이드

이 디렉토리는 쿠버네티스 클러스터 초기화 및 인프라 기본 세팅에 필요한 매니페스트와 설치 가이드를 포함합니다.

## 파일별 설명

### 1. argocd.md
- ArgoCD 설치 방법(Helm) 안내
- 저장소 추가, 네임스페이스 생성, Helm 설치 명령어 제공

### 2. cert-manager.md
- cert-manager 설치 방법(Helm) 안내
- 저장소 추가, CRD 포함 설치 명령어 제공

### 3. cluster-issuer.yaml
- cert-manager용 ClusterIssuer 리소스
- Let's Encrypt(ACME) 기반 인증서 자동 발급 설정

### 4. gcp-standard-storageclass.yaml
- GKE 환경에서 표준 스토리지(StorageClass) 정의
- 동적 볼륨 프로비저닝, 확장, 삭제 정책 등 설정

### 5. flannel.yaml
- Flannel CNI 네트워크 플러그인 전체 매니페스트
- 네임스페이스, RBAC, ConfigMap, DaemonSet 등 포함

---

## 적용 예시

```bash
# cert-manager 설치
kubectl apply -f cert-manager.md (또는 Helm 명령어 참고)

# ClusterIssuer 생성
kubectl apply -f cluster-issuer.yaml

# GKE StorageClass 생성
kubectl apply -f gcp-standard-storageclass.yaml

# Flannel 네트워크 플러그인 설치
kubectl apply -f flannel.yaml
```

---

## 참고

- 각 리소스/가이드는 클러스터 환경(GKE, 인증서, 네트워크 등)에 맞게 수정하여 사용하세요.
- cert-manager, ArgoCD 등은 Helm Chart로 설치하는 것이 권장됩니다. 