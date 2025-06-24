module "vpc" {
  source   = "../../modules/vpc"
  name     = "prod"
  vpc_cidr = "10.0.0.0/16"
}