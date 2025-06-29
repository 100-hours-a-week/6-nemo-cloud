#!/bin/bash
set -e

echo "🧹 Swap 비활성화 중..."
# Kubernetes는 swap이 활성화된 상태에서 작동하지 않기 때문에 swap을 비활성화합니다.
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "🧰 필수 패키지 설치 중..."
# HTTPS 전송, GPG 키 사용을 위한 패키지 설치
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

echo "📦 containerd 설치 및 설정 중..."
# 컨테이너 런타임으로 containerd 사용
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "🌉 브릿지 네트워크 커널 모듈 설정 중..."
# 브릿지 네트워크 트래픽 관련 커널 모듈 설정
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl을 통해 네트워크 설정 반영
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "📥 Kubernetes APT 저장소 등록 중..."
# 최신 Kubernetes 1.30 저장소 등록
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "🔄 kubelet / kubeadm / kubectl 설치 중..."
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
# 버전 고정
sudo apt-mark hold kubelet kubeadm kubectl

echo "✅ 설치 완료! 버전 확인 중..."

# 설치된 버전 확인
kubeadm version
kubectl version --client
kubelet --version

