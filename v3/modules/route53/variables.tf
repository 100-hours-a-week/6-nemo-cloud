variable "domain_name" {
  type = string
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name to point the domain to"
}

variable "alb_zone_id" {
  type        = string
  description = "ALB zone ID"
}