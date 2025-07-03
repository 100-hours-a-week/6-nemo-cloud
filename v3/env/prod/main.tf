module "vpc" {
  source   = "../../modules/vpc"
  name     = "prod"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidr = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  subnet_az = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}


module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "nemo_EKS_kluster"
  cluster_version    = "1.33"

  # 이렇게 변수를 가지고 오고싶을때는 VPC 모듈에서 output으로 가지고 와야함. 
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = [module.vpc.private_azone_id, module.vpc.private_bzone_id, module.vpc.private_czone_id]

  node_group_name    = "nemo_node_group"
  desired_capacity   = 3
  max_capacity       = 3
  min_capacity       = 1
  instance_types     = ["t3.large"]
}


module "argocd" {
  source             = "../../modules/argocd"
  name                = "argocd"
  repository          = "https://argoproj.github.io/argo-helm"
  chart               = "argo-cd"
  namespace           = "argocd"
  create_namespace    = true
  values              = [file("${path.module}/../../modules/argocd/values.yaml")]

  depends_on = [null_resource.update_kubeconfig]
}