variable "name" {
  description = "RDS 인스턴스에 태그로 붙일 이름"
  type        = string
}

variable "identifier" {
  description = "RDS 인스턴스의 고유 식별자"
  type        = string
}

variable "db_name" {
  description = "RDS 데이터베이스 이름"
  type        = string
}

variable "username" {
  description = "RDS 관리자 계정 이름"
  type        = string
}

variable "password" {
  description = "RDS 관리자 계정 비밀번호"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스 (예: db.t3.micro)"
  type        = string
}

variable "allocated_storage" {
  description = "RDS 할당 스토리지 크기 (GiB)"
  type        = number
}

variable "subnet_ids" {
  description = "RDS가 생성될 서브넷 ID 리스트"
  type        = list(string)
}

variable "security_groups" {
  description = "RDS에 적용할 보안 그룹 ID 리스트"
  type        = list(string)
      default = []
}


variable "vpc_id"{
    description =  "id for VPC"
    type        =  string
}
