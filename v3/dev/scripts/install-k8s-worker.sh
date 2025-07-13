#!/bin/bash

# 1. kubelet, containerd 중지
sudo systemctl stop kubelet
sudo systemctl stop containerd

# 2. etcd, kubelet, kubernetes, CNI 등 완전 삭제

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

# 3. iptables 초기화
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# 4. containerd, kubelet 재시작
sudo systemctl restart containerd
sudo systemctl restart kubelet

# 5. (중요) 마스터에서 받은 join 명령어로 클러스터에 조인
# 아래 줄을 실제 마스터에서 받은 join 명령어로 바꿔서 실행하세요!
# 예시:
# sudo kubeadm join <마스터IP>:6443 --token ... --discovery-token-ca-cert-hash ...

echo "==> 반드시 마스터에서 받은 kubeadm join 명령어를 복사해서 실행하세요!" 