# 모듈에서는 var이라고하면 다 다른쪽에서 관리 (prod)

# VPC 그 자체 만들기 
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { 
    Name = "${var.name}-VPC"
  }
}

# 퍼블릭 서브넷-a
resource "aws_subnet" "public-a" {
  cidr_block            = var.public_subnet_cidr[0]
  availability_zone     = var.subnet_az[0]
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-public-azone-subnet"
  }
}

# 퍼블릭 서브넷-c
resource "aws_subnet" "public-c" {
  cidr_block            = var.public_subnet_cidr[1]
  availability_zone     = var.subnet_az[1]
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-public-czone-subnet"
  }
}

#프라이빗 서브넷 
resource "aws_subnet" "private-a" {
  cidr_block            = var.private_subnet_cidr[0]
  availability_zone     = var.subnet_az[0]
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-private-azone-subnet"
  }
}

resource "aws_subnet" "private-c" {
  cidr_block            = var.private_subnet_cidr[1]
  availability_zone     = var.subnet_az[1]
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-private-czone-subnet"
  }
}

# IGW 
resource "aws_internet_gateway" "this"{
  vpc_id                = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-IGW"
  }
}

# 라우팅 테이블 (퍼블릭용)
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

#라우팅 테이블 연결설정 (A)
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.public.id
}
#라우팅 테이블 연결설정 (C)
resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public-c.id
  route_table_id = aws_route_table.public.id
}


# 고정 elastic ip 주소 할당 먼저 받기
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NGW  (a)
resource "aws_nat_gateway" "this" {
  subnet_id     = aws_subnet.public-a.id
  allocation_id = aws_eip.nat.id
  tags = {
    Name = "${var.name}-NGW"
  }
}


# 라우팅 테이블 (프라이빗)
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

# 라우팅 테이블 설정 (A)
resource "aws_route_table_association" "privat-a" {
  subnet_id      = aws_subnet.private-a.id
  route_table_id = aws_route_table.private.id
}

# 라우팅 테이블 설정 (C)
resource "aws_route_table_association" "private-c" {
  subnet_id      = aws_subnet.private-c.id
  route_table_id = aws_route_table.private.id
}