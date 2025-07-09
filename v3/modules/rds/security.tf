### 보안 그룹 생성 
resource "aws_security_group" "rds_sg" {
  name        = "${var.name}-rds-sg"
  description = "Allow MySQL traffic from backend"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    ## add my local address
    cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}