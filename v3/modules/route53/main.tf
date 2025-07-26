# 기존 ALB 정보를 데이터로 가져오기
data "aws_lb" "frontend_alb" {
  tags = {
    "ingress.k8s.aws/stack" = "frontend/frontend"
    "elbv2.k8s.aws/cluster" = var.cluster_name
  }
}

resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "frontend_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.frontend_alb.dns_name
    zone_id                = data.aws_lb.frontend_alb.zone_id
    evaluate_target_health = true
  }
}

