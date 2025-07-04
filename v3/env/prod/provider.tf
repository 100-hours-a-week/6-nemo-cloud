provider "aws" {
  region = "ap-northeast-2"
}

# Helm Provider (EKS 연결 자동화)
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name nemo_EKS_kluster --region ap-northeast-2"
  }
  depends_on = [module.eks]
}