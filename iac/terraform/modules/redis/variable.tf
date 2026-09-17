variable "subnet_elasticache_group" {
  type        = list(string)
  description = "Lista das subnets do grupo subnet do elasticache"
}

variable "aws_vpc_id" {
  type        = string
  description = "Id da VPC onde o security group do Redis sera criado"
}

variable "eks_security_group_id" {
  type        = string
  description = "Security group id do cluster EKS, autorizado a acessar o Redis na porta 6379"
}