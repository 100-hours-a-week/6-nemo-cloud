variable "controller_sa_name" {
  type        = string
  description = "Service account name for the EBS CSI controller"
  default     = "ebs-csi-controller-sa"
}

variable "node_sa_name" {
  type        = string
  description = "Service account name for the EBS CSI node"
  default     = "ebs-csi-node-sa"
}

variable "controller_sa_role_arn" {
  type        = string
  description = "IAM role ARN for the EBS CSI controller service account"
}

variable "kubeconfig_dependency" {
  description = "Resource to depend on for kubeconfig readiness"
  default     = []
}