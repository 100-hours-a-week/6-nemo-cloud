helm repo add jetstack <https://charts.jetstack.io>
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true \
  --version v1.14.2
