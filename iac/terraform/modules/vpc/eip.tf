resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = var.aws_vpc.internet_gateway_name }
}