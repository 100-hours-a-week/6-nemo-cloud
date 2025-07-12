# Nemo Cloud v3 GitOps CI/CD 배포 구조

---

## 🎯 개요

Nemo Cloud v3는 **GitOps 기반 CI/CD 파이프라인**을 도입하여 완전 자동화된 배포 시스템을 구축했습니다.

**핵심 특징:**

- **GitOps 원칙**: Git을 단일 진실 소스로 사용
- **Image Updater**: 이미지 레지스트리 자동 추적
- **멀티 레포지토리**: 애플리케이션과 인프라 분리 관리
- **완전 자동화**: 개발자 개입 최소화

---

## 📁 디렉토리 구조

```
v3/
├── .github/workflows/     # GitHub Actions 워크플로우
│   └── cd-argocd.yaml     # ArgoCD 동기화 (필요시)
├── argocd/                # 🆕 ArgoCD 설정
│   ├── applications/      # ArgoCD Application 정의
│   ├── projects/          # ArgoCD 프로젝트 설정
│   └── image-updater/     # Image Updater 설정
├── k8s/                   # 기존 Helm Chart 구조
│   ├── chart/             # Helm Chart 템플릿
│   ├── infra/             # 인프라 설정
│   ├── kafka/             # Kafka 설정
│   └── raw-manifest/      # 기존 manifest 백업
├── environments/          # 환경별 설치 스크립트
│   └── dev/
├── scripts/               # CI/CD 스크립트
│   ├── update-image-tag.sh
│   └── validate-deployment.sh
├── docs/                  # 🆕 문서화
│   ├── gitops-cicd-overview.md
│   ├── architecture-details.md
│   └── phase1-infrastructure-setup.md
└── README.md              # (이 파일)
```

---

## 🔄 GitOps CI/CD 워크플로우

### 전체 시스템 아키텍처

```
[Backend Repo] → [GitHub Actions CI] → [Image Registry] → [ArgoCD Image Updater] → [ArgoCD] → [K8s]
     ↓              ↓                    ↓                    ↓                    ↓         ↓
   코드 변경    →  빌드/테스트       →  이미지 푸시      →  자동 감지        →  동기화   →  배포
```

### 멀티 레포지토리 구조

```
Repository 1: nemo-backend (Spring Boot)
├── .github/workflows/ci-backend.yaml    # CI 파이프라인
├── src/                                  # 애플리케이션 소스
└── Dockerfile                            # Docker 빌드 설정

Repository 2: nemo-frontend (Next.js)  
├── .github/workflows/ci-frontend.yaml   # CI 파이프라인
├── src/                                  # 애플리케이션 소스
└── Dockerfile                            # Docker 빌드 설정

Repository 3: 6-nemo-cloud (현재 v3)     # 인프라 + ArgoCD
├── argocd/                               # ArgoCD 설정
├── k8s/                                  # Helm Chart
└── docs/                                 # 문서화
```

---

## 🚀 시간순 변화 및 도입 배경

### 1. 초기: 수동 manifest(yaml) 기반 관리

- `k8s/raw-manifest/` 하위에 인프라/앱/DB 등 모든 리소스를 직접 yaml로 관리
- 환경별(dev 등) 디렉토리 분리, 서비스별 deployment/service/configmap/secret 등 수동 작성
- **문제점:**
  - 환경별/서비스별 중복, 실수, 관리 비효율
  - 배포 자동화, 롤백, 불변성 관리 어려움

### 2. Helm 도입 및 구조 전환

- `k8s/chart/`에 Helm Chart 템플릿 구조 도입
  - 서비스별(backend, frontend, ai, mysql, redis 등) 템플릿화
  - `values-common.yaml`, `values-dev.yaml` 등 환경별/공통 values 분리
- 인프라(ingress-nginx, cert-manager 등)는 공식 Helm Chart + values 파일로 관리
  - `infra/dev/`에 환경별 values, manifest 분리
- 네트워크 플러그인 등은 k8s 루트에 별도 관리(`kube-flannel.yml`)
- 기존 manifest는 `raw-manifest/`에 백업/참고용으로만 유지

### 3. 🆕 GitOps CI/CD 도입 (현재)

- **ArgoCD Image Updater** 기반 자동 배포
- **GitHub Actions** CI 파이프라인
- **멀티 레포지토리** 구조로 관심사 분리
- **완전 자동화**된 배포 프로세스

---

## 🎯 핵심 변화 및 실무적 이점

### **이전 vs 현재**

| 구분 | 이전 (Helm) | 현재 (GitOps) |
|------|-------------|---------------|
| 배포 방식 | 수동 Helm 설치 | 자동 ArgoCD 동기화 |
| 이미지 업데이트 | 수동 태그 변경 | 자동 Image Updater |
| 환경 관리 | 수동 values 수정 | Git 기반 선언적 관리 |
| 롤백 | 수동 Helm rollback | Git 히스토리 기반 |
| 모니터링 | 수동 kubectl | ArgoCD UI + 알림 |

### **실무적 이점**

- **🚀 완전 자동화**: 코드 푸시부터 배포까지 자동화
- **🛡️ 안정성**: Git 히스토리 기반 롤백 및 감사
- **📈 확장성**: 새로운 환경/서비스 쉽게 추가
- **🔒 보안**: RBAC 및 네트워크 정책 강화
- **💰 효율성**: 개발자 생산성 대폭 향상

---

## 📚 문서

### 구현 가이드

- [GitOps CI/CD 전체 개요](./docs/gitops-cicd-overview.md)
- [아키텍처 상세 설명](./docs/architecture-details.md)
- [Phase 1: 인프라 준비](./docs/phase1-infrastructure-setup.md)
- [Phase 2: 클라우드 레포 설정](./docs/phase2-cloud-repo-setup.md)
- [Phase 3: Backend CI 설정](./docs/phase3-backend-ci-setup.md)

### 운영 가이드

- [운영 및 모니터링](./docs/operations-monitoring.md)
- [트러블슈팅](./docs/troubleshooting.md)

---

## 🚀 빠른 시작

### 1. 전체 개요 확인

```bash
cat docs/gitops-cicd-overview.md
```

### 2. 단계별 구현

```bash
# Phase 1: 인프라 준비
cat docs/phase1-infrastructure-setup.md

# Phase 2: 클라우드 레포 설정
cat docs/phase2-cloud-repo-setup.md

# Phase 3: Backend CI 설정
cat docs/phase3-backend-ci-setup.md
```

### 3. ArgoCD 상태 확인

```bash
# ArgoCD Application 상태
kubectl get applications -n argocd

# Image Updater 로그
kubectl logs -n argocd deployment/argocd-image-updater
```

---

## 🔧 기술 스택

- **CI/CD**: GitHub Actions, ArgoCD, ArgoCD Image Updater
- **컨테이너**: Docker, Kubernetes
- **패키지 관리**: Helm
- **이미지 레지스트리**: Google Cloud Artifact Registry
- **모니터링**: Prometheus, Grafana

---

**마지막 업데이트**: 2024년 1월  
**버전**: v3.0.0 (GitOps CI/CD)
