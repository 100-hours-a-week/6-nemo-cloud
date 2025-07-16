resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "frontend_alias" {
  zone_id = aws_route53_zone.main.zone_id  # 생성된 Zone ID 참조
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = "k8s-frontend-frontend-af87f59743-182877957.ap-northeast-2.elb.amazonaws.com"
    zone_id                = "ZWKZPGTI48KDX"
    evaluate_target_health = true
  }
}

