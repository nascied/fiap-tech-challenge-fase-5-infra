#-----------------------------------
# Cria subnets publicas
#-----------------------------------

resource "aws_subnet" "private" {
  count = length(var.aws_vpc.private_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.aws_vpc.private_subnets[count.index].cidr_block
  availability_zone       = var.aws_vpc.private_subnets[count.index].availability_zone
  map_public_ip_on_launch = var.aws_vpc.private_subnets[count.index].map_public_ip_on_launch

  tags = { Name = var.aws_vpc.private_subnets[count.index].name }
}

resource "aws_subnet" "public" {
  count = length(var.aws_vpc.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.aws_vpc.public_subnets[count.index].cidr_block
  availability_zone       = var.aws_vpc.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = var.aws_vpc.public_subnets[count.index].map_public_ip_on_launch

  tags = { Name = var.aws_vpc.public_subnets[count.index].name }
}
