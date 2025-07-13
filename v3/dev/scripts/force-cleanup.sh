#!/bin/bash
set -e

echo "🧨 강제 클린업 시작..."

# 1. 모든 k8s 관련 프로세스 강제 종료
echo "🛑 모든 k8s 관련 프로세스 강제 종료..."
sudo pkill -f kube || true
sudo pkill -f etcd || true
sudo pkill -f containerd || true
sudo pkill -f coredns || true
sudo pkill -f flannel || true

# 2. 서비스 중지
echo "⏹️ 서비스 중지..."
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true
sudo systemctl stop etcd || true

# 3. 포트 점유 프로세스 종료
echo "🔌 포트 점유 프로세스 종료..."
for port in 10259 10257 2379 2380 6443 10250 10251 10252 30000 32767; do
  for pid in $(sudo lsof -t -i :$port 2>/dev/null); do
    sudo kill -9 $pid 2>/dev/null || true
  done
done

# 4. 마운트된 모든 볼륨 강제 해제
echo "🔓 마운트된 볼륨 강제 해제..."
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~projected/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~empty-dir/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~configmap/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~secret/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~hostpath/* 2>/dev/null || true
sudo umount -l /var/lib/kubelet/pods/*/volumes/kubernetes.io~persistent-volume-claim/* 2>/dev/null || true

# 5. 점유 프로세스 확인 및 종료
echo "🔍 점유 프로세스 확인 및 종료..."
for pid in $(sudo lsof +D /var/lib/kubelet/pods 2>/dev/null | awk 'NR>1 {print $2}' | sort | uniq); do
    sudo kill -9 $pid 2>/dev/null || true
done

# 6. 모든 k8s 관련 디렉토리 강제 삭제
echo "🗑️ 모든 k8s 관련 디렉토리 강제 삭제..."
sudo rm -rf /var/lib/etcd/member 2>/dev/null || true
sudo rm -rf /var/lib/etcd/* 2>/dev/null || true
sudo rm -rf /var/lib/kubelet/* 2>/dev/null || true
sudo rm -rf /etc/kubernetes/* 2>/dev/null || true
sudo rm -rf /etc/cni/net.d/* 2>/dev/null || true
sudo rm -rf /var/lib/cni/* 2>/dev/null || true
sudo rm -rf /var/run/kubernetes/* 2>/dev/null || true
sudo rm -rf /var/lib/dockershim/* 2>/dev/null || true
sudo rm -rf $HOME/.kube/config 2>/dev/null || true

# 7. iptables 완전 초기화
echo "🧹 iptables 완전 초기화..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo iptables -t nat -X
sudo iptables -t mangle -X

# 8. 네트워크 인터페이스 정리
echo "🌐 네트워크 인터페이스 정리..."
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete docker0 2>/dev/null || true

# 9. 서비스 재시작
echo "🔄 서비스 재시작..."
sudo systemctl restart containerd || true
sudo systemctl restart kubelet || true

echo "✅ 강제 클린업 완료!"
echo "💡 이제 install-k8s-master.sh 또는 install-k8s-worker.sh를 실행하세요." 