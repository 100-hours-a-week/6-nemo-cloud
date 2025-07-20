# 시크릿(Secret) Helm 차트 운영 가이드

## 1. 개요
- 이 차트는 GCP Secret Manager + External Secrets Operator(ESO) 기반으로 쿠버네티스 시크릿을 자동 동기화합니다.
- 네임스페이스별로 values 파일을 분리하여, Helm 릴리스 충돌 없이 안전하게 관리할 수 있습니다.

## 2. 네임스페이스별 values 파일 분리
- values-app.yaml: app 네임스페이스용 (frontend-secret, backend-secret 등)
- values-data.yaml: data 네임스페이스용 (mysql-secret, redis-secret 등)
- 기존 values.yaml은 참고용으로만 남겨두거나 삭제

## 3. 배포 방법
```bash
# app 네임스페이스
helm upgrade --install secrets-app ./charts/secrets -n app -f values-app.yaml

# data 네임스페이스
helm upgrade --install secrets-data ./charts/secrets -n data -f values-data.yaml
```

## 4. 상태 확인
```bash
kubectl get externalsecret -n app
kubectl get externalsecret -n data
kubectl get secret -n app
kubectl get secret -n data
```

## 5. 관리 팁
- 네임스페이스별로 values 파일을 분리하면 Helm 소유권 충돌 없이 안전하게 운영 가능
- 시크릿 생성/동기화 실패 시, gcp-sa-key 시크릿, GCP Secret Manager 내 시크릿 존재 여부, ExternalSecret describe로 상세 원인 확인
- values 파일에 정의된 externalKey, secret 이름, 네임스페이스가 실제 환경과 일치하는지 항상 점검
