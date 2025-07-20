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

  # EKS 클러스터에서의 접근 허용
  dynamic "ingress" {
    for_each = var.eks_security_group_id != "" ? [1] : []
    content {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [var.eks_security_group_id]
    }
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