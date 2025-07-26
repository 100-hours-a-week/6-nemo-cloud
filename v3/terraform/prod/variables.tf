variable "github_pat" {
  description = "GitHub Personal Access Token for ArgoCD Image Updater"
  type        = string
  sensitive   = true
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

# EKS Variables
variable "cluster_name" {
  description = "Name of EKS cluster"
  type        = string
  default     = "nemo_EKS_kluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "node_group_name" {
  description = "Name of EKS node group"
  type        = string
  default     = "nemo_node_group"
}

variable "node_desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "node_max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "node_min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "Instance types for nodes"
  type        = list(string)
  default     = ["t3.large"]
}

variable "key_pair_name" {
  description = "Key pair name for SSH access"
  type        = string
  default     = "keypair-kube-master"
}

# RDS Variables
variable "rds_password" {
  description = "Password for RDS instance"
  type        = string
  sensitive   = true
}

variable "rds_username" {
  description = "Username for RDS instance"
  type        = string
  default     = "prod"
}

variable "rds_db_name" {
  description = "Database name"
  type        = string
  default     = "prod_db"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS"
  type        = number
  default     = 20
}

# Lambda Variables
variable "ec2_instance_ids" {
  description = "List of EC2 instance IDs to control"
  type        = string
  sensitive   = true
}

# Bastion Variables
variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t2.medium"
}

variable "bastion_ami_id" {
  description = "AMI ID for bastion host"
  type        = string
  default     = "ami-0662f4965dfc70aca"
}

# Route53 Variables
variable "domain_name" {
  description = "Domain name for Route53"
  type        = string
  default     = "onurivit01.store"
}

# General Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}
