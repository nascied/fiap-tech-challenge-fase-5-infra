output "aws_ecr_repository_arn" {
  value = [for i in aws_ecr_repository.this : i.arn]
}

output "aws_ecr_repository_registry_id" {
  value = [for i in aws_ecr_repository.this : i.registry_id]
}

output "aws_ecr_repository_repository_url" {
  value = [for i in aws_ecr_repository.this : i.repository_url]
}