variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig for Helm provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL (from EKS)"
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN (from IAM OIDC)"
}

variable "aws_account_id" {
  type        = string
  description = "Your AWS Account ID"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "github_pat" {
  description = "GitHub Personal Access Token for ArgoCD Image Updater"
  type      = string
  sensitive = true
}
