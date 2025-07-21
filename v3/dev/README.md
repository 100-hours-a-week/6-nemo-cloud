# 6-Nemo-Cloud GitOps 구조

## 📊 프로젝트 개요

이 프로젝트는 쿠버네티스 기반의 클라우드 네이티브 애플리케이션을 GitOps 방식으로 관리하는 인프라 코드입니다.

## 🏗️ 디렉토리 구조

```
6-nemo-cloud/v3/dev/
├── 📁 argocd-applications/          # ArgoCD Application 정의
│   ├── 📁 applications/             # 애플리케이션 Application (차트화)
│   ├── 📁 data/                     # 데이터베이스 Application (차트화)
│   ├── 📁 infrastructure/           # 인프라 Application (외부화)
│   ├── 📁 networking/               # 네트워킹 Application (차트화)
│   └── 📁 secrets/                  # 시크릿 Application (차트화)
│
├── 📁 bootstrap/                    # 클러스터 초기화 (수동 설치)
│   ├── 📄 README.md                 # 가이드 문서
│   ├── 📄 argocd.md                 # ArgoCD 설치 명령어
│   ├── 📄 cert-manager.md           # cert-manager 설치 명령어
│   ├── 📄 cluster-issuer.yaml       # Let's Encrypt ClusterIssuer
│   ├── 📄 flannel.yaml              # Flannel CNI 매니페스트
│   └── 📄 local-storage-path.md     # local-path 설치 명령어
│
├── 📁 charts/                       # Helm Charts (회사 특화)
│   ├── 📁 app/                      # 애플리케이션 차트
│   │   ├── 📁 ai/                   # AI 서비스 차트
│   │   ├── 📁 backend/              # 백엔드 차트
│   │   └── 📁 frontend/             # 프론트엔드 차트
│   ├── 📁 data/                     # 데이터베이스 차트
│   │   ├── 📁 mysql/                # MySQL 차트
│   │   └── 📁 redis/                # Redis 차트
│   ├── 📁 infra/                    # 인프라 차트
│   │   ├── 📁 app-ingress/          # 애플리케이션 인그레스
│   │   ├── 📁 argocd-ingress/       # ArgoCD 인그레스
│   │   └── 📁 cluster-issuer/       # ClusterIssuer
│   └── 📁 secrets/                  # 시크릿 관리 차트
│
├── 📁 raw-manifest/                 # 레거시 매니페스트 (사용 안함)
└── 📁 scripts/                      # 배포 스크립트
```

## 🎯 GitOps 관리 전략

### 하이브리드 접근법 (Hybrid Approach)

현업 표준을 따라 핵심 비즈니스 로직은 차트화하고, 표준 인프라 도구는 외부 저장소를 사용합니다.

#### ✅ 차트화 (회사 특화) - Helm Charts 사용

**Applications (핵심 비즈니스 로직)**
- `backend/` - 백엔드 애플리케이션
- `frontend/` - 프론트엔드 애플리케이션  
- `ai/` - AI 서비스
- `app-ingress/` - 애플리케이션 인그레스

**Data (데이터 안정성)**
- `mysql/` - MySQL 데이터베이스
- `redis/` - Redis 캐시

**Networking (회사 정책)**
- `argocd-ingress/` - ArgoCD 인그레스
- `cluster-issuer/` - Let's Encrypt ClusterIssuer

**Secrets (보안 정책)**
- `secrets/` - GCP Secret Manager 연동

**이유:**
- 회사 특화 설정 (이미지, 환경변수, 리소스)
- 자주 변경되는 로직
- 데이터 손실 위험
- 보안 정책 적용

#### 🌐 외부화 (표준 도구) - 외부 Helm 저장소 사용

**Infrastructure (표준 인프라 도구)**
- `cert-manager` - https://charts.jetstack.io
- `external-secrets` - https://charts.external-secrets.io
- `ingress-nginx` - https://kubernetes.github.io/ingress-nginx
- `local-path-storage` - raw manifest
- `kube-flannel` - raw manifest

**Data (표준 메시징)**
- `kafka` - https://charts.bitnami.com/kafka

**이유:**
- 표준화된 도구
- 자동 보안 업데이트
- 커뮤니티 검증
- 유지보수 부담 없음

#### ⚠️ 제외

**ArgoCD 자체**
- 순환 참조 위험으로 수동 관리 유지

## 📋 ArgoCD Application 구조

### 1. Applications (차트화)
```yaml
argocd-applications/applications/
├── backend.yaml          # charts/app/backend
├── frontend.yaml         # charts/app/frontend
├── ai.yaml              # charts/app/ai
└── app-ingress.yaml     # charts/infra/app-ingress
```

### 2. Data (차트화)
```yaml
argocd-applications/data/
├── mysql.yaml           # charts/data/mysql
└── redis.yaml           # charts/data/redis
```

### 3. Infrastructure (외부화)
```yaml
argocd-applications/infrastructure/
├── cert-manager.yaml        # https://charts.jetstack.io
├── external-secrets.yaml    # https://charts.external-secrets.io
├── ingress-nginx.yaml       # https://kubernetes.github.io/ingress-nginx
├── local-path-storage.yaml  # raw manifest
└── kube-flannel.yaml        # bootstrap/flannel.yaml
```

### 4. Networking (차트화)
```yaml
argocd-applications/networking/
├── argocd-ingress.yaml      # charts/infra/argocd-ingress
└── cluster-issuer.yaml      # charts/infra/cluster-issuer
```

### 5. Secrets (차트화)
```yaml
argocd-applications/secrets/
├── secrets-app.yaml         # charts/secrets (values-app.yaml)
└── secrets-data.yaml        # charts/secrets (values-data.yaml)
```

### 6. Data (외부화)
```yaml
argocd-applications/data/
└── kafka.yaml              # https://charts.bitnami.com/kafka
```

## 🚀 배포 순서

### Phase 1: 차트화된 리소스 (8개)
```bash
# 1. Applications
kubectl apply -f argocd-applications/applications/

# 2. Data (차트화)
kubectl apply -f argocd-applications/data/mysql.yaml
kubectl apply -f argocd-applications/data/redis.yaml

# 3. Networking
kubectl apply -f argocd-applications/networking/

# 4. Secrets
kubectl apply -f argocd-applications/secrets/
```

### Phase 2: 외부화된 리소스 (6개)
```bash
# 1. Infrastructure
kubectl apply -f argocd-applications/infrastructure/

# 2. Data (외부화)
kubectl apply -f argocd-applications/data/kafka.yaml
```

### Phase 3: 기존 리소스 마이그레이션
```bash
# 기존 수동 설치된 리소스들을 ArgoCD로 전환
# 단계별로 진행하여 안정성 확보
```

## 📊 분류 요약

| 구분 | 차트화 | 외부화 | 제외 |
|------|--------|--------|------|
| **Applications** | 4개 | - | - |
| **Data** | 2개 | 1개 | - |
| **Infrastructure** | - | 5개 | - |
| **Networking** | 2개 | - | - |
| **Secrets** | 2개 | - | - |
| **ArgoCD** | - | - | 1개 |
| **총계** | 10개 | 6개 | 1개 |

## 🔧 관리 방식

### 차트화된 리소스
- Git에서 모든 변경사항 추적
- 코드 리뷰 필수
- 회사 정책 적용
- 환경별 커스터마이징

### 외부화된 리소스
- 자동 업데이트
- 보안 패치 자동 적용
- 커뮤니티 검증
- 유지보수 부담 없음

## 🏢 현업 표준

이 구조는 현업에서 가장 일반적으로 사용하는 **하이브리드 접근법**입니다:

- **대기업**: 완전 차트화 (보안/규제)
- **스타트업**: 외부 저장소 중심 (속도)
- **중견기업**: 하이브리드 (균형) ← **현재 방식**

## 📝 참고사항

- 모든 변경사항은 Git을 통해 관리
- ArgoCD가 Git 변경사항을 감지하여 자동 배포
- 문제 발생 시 빠른 롤백 가능
- 환경별 설정 분리 (dev/staging/prod) 