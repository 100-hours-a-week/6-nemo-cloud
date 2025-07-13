#!/bin/bash
set -e

# 🧹 Swap 비활성화 중...
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 🧰 필수 패키지 설치 중...
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# 📦 containerd 설치 및 설정 중...
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd

# 🌉 브릿지 네트워크 커널 모듈 설정 중...
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# 📥 Kubernetes APT 저장소 등록 중...
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# 🔄 kubelet / kubeadm / kubectl 설치 중...
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "✅ 설치 완료! 버전 확인 중..."
kubeadm version
kubectl version --client
kubelet --version

# === 클러스터 완전 클린 초기화 ===

# 0. 남아있는 프로세스 강제 종료 및 포트 점유 해제
echo "🛑 남아있는 k8s/etcd 프로세스 강제 종료 및 포트 점유 해제..."
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true
sudo pkill -f kube || true
sudo pkill -f etcd || true
sudo pkill -f containerd || true
for port in 10259 10257 2379 2380; do
  for pid in $(sudo lsof -t -i :$port); do
    sudo kill -9 $pid || true
  done
done

# 1. etcd, kubelet, kubernetes, CNI, kubeconfig 등 완전 삭제
echo "🧹 etcd, kubelet, kubernetes, CNI, kubeconfig 등 완전 삭제..."

# 마운트된 볼륨 먼저 해제
echo "🔓 마운트된 볼륨 해제 중..."
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~projected/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~empty-dir/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~configmap/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~secret/* 2>/dev/null || true

# 점유 프로세스 확인 및 종료
echo "🔍 점유 프로세스 확인 및 종료..."
for pid in $(sudo lsof +D /var/lib/kubelet/pods 2>/dev/null | awk 'NR>1 {print $2}' | sort | uniq); do
    sudo kill -9 $pid 2>/dev/null || true
done

# 디렉토리 삭제 (에러 무시)
echo "🗑️ 디렉토리 삭제 중..."
sudo rm -rf /var/lib/etcd/* 2>/dev/null || true
sudo rm -rf /var/lib/kubelet/* 2>/dev/null || true
sudo rm -rf /etc/kubernetes/* 2>/dev/null || true
sudo rm -rf /etc/cni/net.d/* 2>/dev/null || true
sudo rm -rf $HOME/.kube/config 2>/dev/null || true

# 2. iptables 초기화
echo "🧹 iptables 초기화..."
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# 3. containerd, kubelet 재시작
echo "🔄 containerd, kubelet 재시작..."
sudo systemctl restart containerd
sudo systemctl restart kubelet

# 4. 클러스터 재초기화
echo "🚀 kubeadm init..."
# kubeadm init 실패해도 스크립트가 종료되지 않도록
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 || true

# 5. kubectl 설정
echo "🔑 kubectl 설정..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 6. 네트워크 플러그인(flannel 등) 설치
echo "🌐 flannel 네트워크 플러그인 설치..."
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
FLANNEL_YAML="$SCRIPT_DIR/../infra/bootstrap/kube-flannel.yml"

# kube-apiserver가 뜰 때까지 대기
echo "⏳ kube-apiserver 준비 대기 중..."
for i in {1..30}; do
  if kubectl get nodes &>/dev/null; then
    break
  fi
  sleep 5
done

kubectl apply -f "$FLANNEL_YAML"

# CoreDNS 재적용 시도 (kubeadm init에서 실패했을 경우)
echo "🔄 CoreDNS 재적용 시도..."
sudo kubeadm init phase addon coredns || true

echo "✅ 마스터 노드 클린 초기화 및 네트워크 플러그인 설치 완료!"

