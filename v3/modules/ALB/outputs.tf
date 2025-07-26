output "iam_role_arn" {
  description = "ALB Ingress Controller에 연결된 IAM Role ARN"
  value       = aws_iam_role.alb_ingress.arn
}