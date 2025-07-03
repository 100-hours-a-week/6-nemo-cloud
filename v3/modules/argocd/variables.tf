variable "name" {
  description = "Helm release name"
  type        = string
}

variable "repository" {
  description = "Helm chart repository"
  type        = string
}

variable "chart" {
    description = "Helm chart name"
    type        = string
}

variable "namespace" {
    description =  "Kubernetes namespace for ArgoCD"
    type        =  string
}

variable "create_namespace" {
    description =  "Whether to create the namespace"
    type        =  bool
    default     =  true
}

variable "values" {
  description = "List of values files"
  type        = list(string)
  default     = []
}