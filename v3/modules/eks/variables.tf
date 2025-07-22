variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_group_name" {
  type = string
}

variable "desired_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "instance_types" {
  type    = list(string)
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block for security group rules"
}

variable "key_pair_name" {
  type        = string
  description = "EC2 Key Pair name for SSH access"
  default     = ""
}