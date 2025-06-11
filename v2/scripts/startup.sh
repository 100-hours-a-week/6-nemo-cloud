#!/bin/bash
set -euo pipefail

echo "[startup] 기본 패키지 업데이트"
apt-get update -y

echo "[startup] Docker 설치"
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

echo "[startup] gcloud CLI 설치"
apt-get install -y curl apt-transport-https ca-certificates gnupg
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  > /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update -y && apt-get install -y google-cloud-cli

echo "[startup] 환경변수 로딩"
if ! gcloud secrets versions access latest \
  --secret=${SERVICE}-${ENV}-env \
  --project=${GCP_PROJECT_ID_PROD} > /root/.env; then
  echo "[startup][ERROR] 환경변수 로딩 실패"
  exit 1
fi

echo "[startup] Docker 인증"
gcloud auth configure-docker asia-northeast3-docker.pkg.dev --quiet

echo "[startup] 이미지 Pull"
if ! docker pull ${IMAGE}; then
  echo "[startup][ERROR] 이미지 Pull 실패"
  exit 1
fi

echo "[startup] 컨테이너 실행"
if ! docker run -d --name ${SERVICE} --restart=always \
  --env-file /root/.env -p ${PORT}:${PORT} ${IMAGE}; then
  echo "[startup][ERROR] 컨테이너 실행 실패"
  docker logs ${SERVICE} || true
  exit 1
fi
