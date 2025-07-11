apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-registry
  namespace: argocd
data:
  registries.conf.yaml: |
%{ for line in split("\n", file("${path.module}/../../helm-charts/argocd-image-updater/registries.conf.yaml")) ~}
    ${line}
%{ endfor ~}