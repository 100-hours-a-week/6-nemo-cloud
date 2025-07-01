variable "name" {
  description = "Prefix name for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
    description = "public subnet CIDR"
    type = list(string)
}

variable "private_subnet_cidr" {
    description = "private subnet CIDR"
    type = list(string)
}

variable "subnet_az" {
  type        = list(string)
  description = "Availability zones to use"
}