resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { 
    Name = "v3-nemo-${var.name}-vpc"
  }
}

resource "aws_subnet" "public" {
  cidr_block            = var.public_subnet_cidr
  availability_zone     = var.subnet_az[0]
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-public-subnet"
  }
}

resource "aws_subnet" "private" {
  cidr_block            = var.private_subnet_cidr
  availability_zone     = var.subnet_az[0]
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-private-subnet"
  }
}