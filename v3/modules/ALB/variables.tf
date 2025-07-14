variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "region" {
  description = "AWS 리전"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  type        = string
}