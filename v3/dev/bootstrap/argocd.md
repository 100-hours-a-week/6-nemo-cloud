helm repo add argo-cd <https://argoproj.github.io/argo-helm>
helm repo update

kubectl create namespace argocd

helm install argocd argo-cd/argo-cd -n argocd
