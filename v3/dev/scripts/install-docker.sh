#!/bin/bash

# Docker 설치 스크립트 for Ubuntu
# 실행 권한: chmod +x install-docker.sh

echo "🚀 Docker 설치를 시작합니다..."

# 기존 Docker 패키지 제거 (있다면)
echo "📦 기존 Docker 패키지 제거 중..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# 필요한 패키지 설치
echo "📦 필요한 패키지 설치 중..."
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Docker의 공식 GPG 키 추가
echo "🔑 Docker GPG 키 추가 중..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Docker 저장소 추가
echo "📚 Docker 저장소 추가 중..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker Engine 설치
echo "🔧 Docker Engine 설치 중..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 현재 사용자를 docker 그룹에 추가
echo "👤 사용자를 docker 그룹에 추가 중..."
sudo usermod -aG docker $USER

# Docker 서비스 시작 및 활성화
echo "🔄 Docker 서비스 시작 중..."
sudo systemctl start docker
sudo systemctl enable docker

# Docker Compose 설치 (별도)
echo "📦 Docker Compose 설치 중..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 설치 확인
echo "✅ 설치 확인 중..."
docker --version
docker-compose --version

echo ""
echo "🎉 Docker 설치가 완료되었습니다!"
echo "⚠️  중요: 변경사항을 적용하려면 시스템을 재부팅하거나 새 터미널 세션을 시작하세요."
echo ""
echo "사용 예시:"
echo "  docker --version"
echo "  docker run hello-world"
echo "  docker-compose --version"

# chmod +x install-docker.sh
# ./install-docker.sh