variable "domain_name" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name for ALB lookup"
  type        = string
}