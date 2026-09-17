#------------------------
# Cria recurso de VPC
#------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.aws_vpc.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Name = var.aws_vpc.name
  }
}
