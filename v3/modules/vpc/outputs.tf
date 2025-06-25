output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

output "private_azone_id" {
  description   = "ID for private_azone_id"
  value         = aws_subnet.private-a.id
}

output "private_czone_id" {
  description   = "ID for private_czone_id"
  value         = aws_subnet.private-c.id
}