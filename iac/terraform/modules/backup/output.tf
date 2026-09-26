output "backup_vault_arn" {
  description = "ARN do AWS Backup vault"
  value       = aws_backup_vault.this.arn
}

output "backup_vault_name" {
  description = "Nome do AWS Backup vault"
  value       = aws_backup_vault.this.name
}

output "backup_plan_id" {
  description = "ID do plano de backup"
  value       = aws_backup_plan.this.id
}

output "backup_plan_arn" {
  description = "ARN do plano de backup"
  value       = aws_backup_plan.this.arn
}

output "sns_topic_arn" {
  description = "ARN do tópico SNS de notificação de jobs de backup/restore"
  value       = aws_sns_topic.this.arn
}

output "velero_bucket_name" {
  description = "Nome do bucket S3 usado pelo Velero"
  value       = local.velero_bucket_name
  depends_on  = [null_resource.velero_bucket]
}

output "velero_bucket_arn" {
  description = "ARN do bucket S3 usado pelo Velero"
  value       = "arn:aws:s3:::${local.velero_bucket_name}"
  depends_on  = [null_resource.velero_bucket]
}
