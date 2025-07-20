# Infra Helm Charts

이 디렉토리는 쿠버네티스 인프라 구성에 필요한 Helm 차트 모음입니다.

## 구성 차트

### 1. argocd-ingress
- **설명:** ArgoCD 서버용 Ingress 리소스 배포
- **주요 변수:**  
  - `namespace`, `host`, `tlsSecret`, `service`, `port`, `path`
- **특징:**  
  - nginx ingress, cert-manager 연동, HTTPS 백엔드 지원

### 2. app-ingress
- **설명:** 여러 서비스(backend, ai, frontend 등) 경로 기반 Ingress 리소스 배포
- **주요 변수:**  
  - `namespace`, `host`, `tlsSecret`, `rules`(경로/서비스/포트 반복)
- **특징:**  
  - 다양한 경로 라우팅, nginx/cert-manager 어노테이션

### 3. ingress-nginx
- **설명:** NGINX Ingress Controller 배포용 차트
- **주요 변수:**  
  - `controller.replicaCount`, `controller.ingressClass`, `controller.service.nodePorts` 등
- **특징:**  
  - NodePort 타입, 메트릭, 리소스 제한 등 커스터마이즈 가능

---

## 배포 예시

```bash
# argocd-ingress 배포
helm upgrade --install argocd-ingress ./argocd-ingress

# app-ingress 배포
helm upgrade --install app-ingress ./app-ingress

# ingress-nginx 배포
helm upgrade --install ingress-nginx ./ingress-nginx
```

---

## 참고

- 각 차트의 values.yaml을 참고하여 환경에 맞게 변수 값을 수정하세요.
- cert-manager, nginx ingress controller 등 인프라 선행 설치가 필요할 수 있습니다. 