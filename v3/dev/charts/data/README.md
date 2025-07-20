# 데이터 티어(Helm 차트) 운영환경 배포 가이드

## 1. 개요
- 이 디렉토리는 MySQL, Redis 등 데이터 티어를 Helm 차트로 배포/운영하기 위한 리소스를 포함합니다.
- 운영환경 수준의 시크릿 관리(ESO), PVC, 리소스 제한, 헬스체크, 네임스페이스 분리 등 실전 배포 기준으로 구성되어 있습니다.

## 2. 사전 준비
- local-path 등 환경에 맞는 StorageClass가 준비되어 있어야 합니다.
- GCP Secret Manager + External Secrets Operator(ESO) 기반 시크릿 자동화 환경이 구축되어 있어야 합니다.
- 네임스페이스: data

## 3. 시크릿(Secret) 연동
- 시크릿은 ESO(External Secrets Operator)로 GCP Secret Manager에서 자동 동기화됩니다.
- charts/secrets/values-data.yaml에 data 네임스페이스용 시크릿 정의 필요
- 예시:
  - mysql-secret: MYSQL_ROOT_PASSWORD, database, user, password 등
  - redis-secret: redis-password

## 4. 배포 방법

### 1) 시크릿(ESO) 배포
```bash
helm upgrade --install secrets-data /home/ubuntu/6-nemo-cloud/v3/dev/charts/secrets -n data -f /home/ubuntu/6-nemo-cloud/v3/dev/charts/secrets/values-data.yaml
```

### 2) 데이터 티어 배포
```bash
helm upgrade --install mysql ./charts/data/mysql -n data
helm upgrade --install redis ./charts/data/redis -n data
```

## 5. 상태 확인
```bash
kubectl get externalsecret -n data
kubectl get secret -n data
kubectl get pod -n data -o wide
kubectl get pvc -n data
kubectl get svc -n data
```

## 6. 운영환경 기준 주요 설정
- 리소스 제한, 헬스체크(livenessProbe/readinessProbe) 적용
- StorageClass, PVC, 시크릿 등 환경별 커스터마이즈 가능
- values.yaml로 환경별 파라미터 관리
- StatefulSet replicas: 1 (운영환경 기준)

## 7. 문제 해결 팁
- PVC Pending: StorageClass, PV 상태 확인
- Pod CreateContainerConfigError: 시크릿 존재 여부, 값 확인
- ExternalSecret STATUS가 Error: gcp-sa-key 등 인증정보, GCP 시크릿 존재 여부 확인

## 8. 참고
- 운영환경에서는 반드시 시크릿, 스토리지, 리소스 제한 등 Harden 권장
- ArgoCD 등 GitOps 전환 시 charts/argocd 참고 