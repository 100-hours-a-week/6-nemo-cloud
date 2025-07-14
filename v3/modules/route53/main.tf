resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "frontend_alias" {
  zone_id = "Z09133841Z94Z8Z7ECYRA"          
  name    = var.domain_name  # 하드코딩 대신 변수 사용
  type    = "A"

  alias {
    name                   = "ab2181d547c2a4217b2a7ad51fdf1501-434874446.ap-northeast-2.elb.amazonaws.com"
    zone_id                = "Z3AQBSTGFYJSTF" # 서울 리전 ALB zone id
    evaluate_target_health = true
  }
}
