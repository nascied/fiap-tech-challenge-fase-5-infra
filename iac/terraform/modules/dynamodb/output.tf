# ============================================================
# OUTPUTS
# ============================================================

output "aws_dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = aws_dynamodb_table.this.name
}

output "aws_dynamodb_table_arn" {
  description = "ARN da tabela"
  value       = aws_dynamodb_table.this.arn
}

output "aws_dynamodb_table_id" {
  description = "ID da tabela"
  value       = aws_dynamodb_table.this.id
}