resource "aws_db_subnet_group" "this" {
  name        = var.name
  subnet_ids = var.subnet_ids
  tags = {
    Name = var.name
  }
}




resource "aws_db_instance" "this" {
  identifier              = var.identifier
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  ## 보안그룹
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  deletion_protection     = false
  publicly_accessible     = false
  multi_az                = true
  storage_encrypted       = true
  apply_immediately       = true
  tags = {
    Name = var.name
  }
}