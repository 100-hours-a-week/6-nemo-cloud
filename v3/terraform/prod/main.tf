module "vpc" {
  source   = "../../modules/vpc"
  name     = var.environment
  vpc_cidr = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidrs
  private_subnet_cidr = var.private_subnet_cidrs
  subnet_az = var.availability_zones
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version

  # 이렇게 변수를 가지고 오고싶을때는 VPC 모듈에서 output으로 가지고 와야함. 
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  subnet_ids         = [module.vpc.private_azone_id, module.vpc.private_bzone_id, module.vpc.private_czone_id]

  node_group_name    = var.node_group_name
  desired_capacity   = var.node_desired_capacity
  max_capacity       = var.node_max_capacity
  min_capacity       = var.node_min_capacity
  instance_types     = var.node_instance_types
  key_pair_name      = var.key_pair_name  # SSH 접근용 키페어
}

module "ebs_csi_driver" {
  source = "../../modules/ebs"
  
  controller_sa_name      = "ebs-csi-controller-sa"
  controller_sa_role_arn  = "arn:aws:iam::084375578827:role/${var.cluster_name}-ebs-csi-driver"
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
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
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
    INSTANCE_IDS = var.ec2_instance_ids
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



module "rds" {
  source = "../../modules/rds"


  name               = "${var.environment}-rds"
  identifier         = "nemo-db-instance"
  db_name            = var.rds_db_name
  username           = var.rds_username
  password           = var.rds_password             # 보안상 tfvars에서 관리
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage

  vpc_id             = module.vpc.vpc_id
  eks_security_group_id = module.eks.cluster_security_group_id

  subnet_ids = [
    module.vpc.private_azone_id,
    module.vpc.private_bzone_id,
    module.vpc.private_czone_id
  ] # output에서 가지고옴 

}

module "bastion" {
  source     = "../../modules/bastion"

  vpc_id     = module.vpc.vpc_id
  instance_type = var.bastion_instance_type
  subnet_id  = module.vpc.public_azone_id
  ami_id     = var.bastion_ami_id
  key_name   = var.key_pair_name
  name       = "${var.environment}-bastion"
}

module "route53" {
  source       = "../../modules/route53"
  domain_name  = var.domain_name
  cluster_name = var.cluster_name
  
  # ALB가 생성된 후에 실행되도록 의존성 추가
  depends_on = [
    module.alb_ingress_controller,
    null_resource.update_kubeconfig
  ]
}

output "ns" {
  value = module.route53.ns
}


module "alb_ingress_controller" {
  source            = "../../modules/ALB"
  cluster_name      = var.cluster_name
  region            = var.aws_region
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
}

module "argocd_image_updater" {
  source = "../../modules/argocd_image_updater"
  
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  aws_account_id    = data.aws_caller_identity.current.account_id
  region            = var.aws_region
  github_pat        = var.github_pat
  kubeconfig_path   = "~/.kube/config"
  
  depends_on = [module.argocd]
}
