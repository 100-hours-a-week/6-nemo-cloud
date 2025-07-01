resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { 
    Name = "${var.name}-VPC"
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

resource "aws_internet_gateway" "this"{
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-IGW"
  }
}

resource "aws_route_table" "public" {
  vpc_id                = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.name}-public-RT"
  }
}


resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}







resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id
  tags = {
    Name = "${var.name}-NGW"
  }
}

resource "aws_route_table" "private" {
  vpc_id                = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    Name = "${var.name}-private-RT"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}