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
  runtime            = "nodejs20.x"
  handler            = "index.handler"
  lambda_zip_path    = "${path.module}/files/ec2_control_lambda.zip" 

  environment_variables = {
    ACTION       = "stop"
    INSTANCE_IDS = "i-0a2523d2264e00cc1,i-0e1b82109a5114d49,i-0eec3bf4bf30a4ddb"
  }
}