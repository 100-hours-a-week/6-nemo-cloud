provider "aws" {
  region = "ap-northeast-2"
}

# Helm Provider (EKS 연결 자동화)
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}