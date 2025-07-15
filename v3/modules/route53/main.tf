resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "frontend_alias" {
  zone_id = "Z09133841Z94Z8Z7ECYRA"         
  name    = var.domain_name  # 하드코딩 대신 변수 사용
  type    = "A"

  alias {
    name                   = "k8s-frontend-frontend-af87f59743-182877957.ap-northeast-2.elb.amazonaws.com"
    zone_id                = "ZWKZPGTI48KDX"
    evaluate_target_health = true
  }
}

