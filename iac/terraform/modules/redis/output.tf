output "aws_elasticache_cluster_arn" {
  value = aws_elasticache_cluster.this.arn
}

output "aws_elasticache_cluster_engine_version_actual" {
  value = aws_elasticache_cluster.this.engine_version_actual
}

output "aws_elasticache_cluster_cache_nodes" {
  value = aws_elasticache_cluster.this.cache_nodes
}

output "aws_elasticache_cluster_cluster_address" {
  value = aws_elasticache_cluster.this.cluster_address
}

output "aws_elasticache_cluster_configuration_endpoint" {
  value = aws_elasticache_cluster.this.configuration_endpoint
}

output "aws_security_group_id" {
  description = "Id do security group do Redis"
  value       = aws_security_group.this.id
}