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
  min_capacity       = 3
  instance_types     = ["t3.large"]
}

module "ebs_csi_driver" {
  source = "../../modules/ebs"
  
  controller_sa_name      = "ebs-csi-controller-sa"
  controller_sa_role_arn  = "arn:aws:iam::084375578827:role/nemo_EKS_kluster-ebs-csi-driver"
  node_sa_name            = "ebs-csi-node-sa"
  kubeconfig_dependency   = null_resource.update_kubeconfig
}

# install ArgoCD as HELM 
module "argocd" {
  source             = "../../modules/argocd"
  name                = "argocd"
  repository          = "https://argoproj.github.io/argo-helm"
  chart               = "argo-cd"
  namespace           = "argocd"
  create_namespace    = true
  values              = [file("${path.module}/../../modules/argocd/values.yaml")]

  ## 중요 
  depends_on = [null_resource.update_kubeconfig]
}


resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name nemo_EKS_kluster --region ap-northeast-2"
  }
  ## EKS가 다끝나고 다음 명령어 생성하기 
  depends_on = [module.eks]
}


module "lambda_ec2_control" {
  source = "../../modules/lambda"

  lambda_name        = "eks-ec2-startstop"
  role_name          = "lambda-ec2-control-role"
  policy_name        = "lambda-ec2-control-policy"
  runtime            = "nodejs18.x"
  handler            = "index.handler"
  lambda_zip_path    = "${path.module}/files/ec2_control_lambda.zip" 

  environment_variables = {
    ACTION       = "start"
    INSTANCE_IDS = "i-0657dd55aea798a8e,i-03596f9222f2ea70b,i-0869ce93a892491b9"
  }
}

data "aws_caller_identity" "current" {}


module "secret" {
  source = "../../modules/secret"

  providers = {
    helm = helm
  }

  kubeconfig_path     = "~/.kube/config"
  oidc_provider_url   = module.eks.oidc_provider_url
  oidc_provider_arn   = module.eks.oidc_provider_arn
}


module "argocd_image_updater" {
  source             = "../../modules/argocd_image_updater"

  # provider가 모듈내부에 없고
  providers = {
    helm = helm
  }

  kubeconfig_path    = "~/.kube/config"
  oidc_provider_url  = module.eks.oidc_provider_url
  oidc_provider_arn  = module.eks.oidc_provider_arn
  aws_account_id     = "084375578827"
  region             = "ap-northeast-2"
  github_pat         = var.github_pat
}






module "rds" {
  source = "../../modules/rds"


  name               = "v3-prod-rds"
  identifier         = "nemo-db-instance"
  db_name            = "prod_db"
  username           = "prod"
  password           = "Prod1234!"             # 보안상 tfvars에서 관리
  instance_class     = "db.t3.micro"
  allocated_storage  = 20

  vpc_id             = module.vpc.vpc_id

  subnet_ids = [
    module.vpc.private_azone_id,
    module.vpc.private_bzone_id,
    module.vpc.private_czone_id
  ] # output에서 가지고옴 

}

module "bastion" {
  source     = "../../modules/bastion"

  vpc_id     = module.vpc.vpc_id
  instance_type = "t2.medium"
  subnet_id  = module.vpc.public_azone_id
  ami_id     = "ami-0662f4965dfc70aca"
  key_name   = "keypair-kube-master"
  name       = "v3-prod"
}

module "route53" {
  source      = "../../modules/route53"
  domain_name = "onurvit01.shop"
}

output "ns" {
  value = module.route53.ns
}