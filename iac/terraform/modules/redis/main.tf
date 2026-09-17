resource "aws_security_group" "this" {
  name        = "${local.resource_prefix_name}-redis-sg"
  description = "Security group para ElastiCache Redis"
  vpc_id      = var.aws_vpc_id

  ingress {
    description     = "Acesso do EKS (nodes/pods) ao Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.resource_prefix_name}-redis-sg"
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${local.resource_prefix_name}-cache"
  subnet_ids = var.subnet_elasticache_group
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${local.resource_prefix_name}-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  apply_immediately = true

  tags = {
    Name = "${local.resource_prefix_name}-cache"
  }
}