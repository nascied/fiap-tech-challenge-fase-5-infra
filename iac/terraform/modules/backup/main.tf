#
# AWS Backup: protege RDS (donation-service, ngo-service) e DynamoDB
# (SolidaryTechVolunteers) via seleção por tag (Backup = "true").
#
# Limitações da conta AWS Academy (Learner Lab), documentadas no DRP.md:
#   - sem cópia cross-region (só uma região habilitada)
#   - sem AWS Backup Vault Lock (exige permissão que a conta não concede)
#   - sem KMS customer-managed key própria (usa a KMS key gerenciada aws/backup)
#   - sem IAM role própria (reaproveita a LabRole via data.tf)
#

resource "aws_backup_vault" "this" {
  name = var.vault_name
}

resource "aws_backup_plan" "this" {
  name = "${var.vault_name}-plan"

  rule {
    rule_name         = "${var.vault_name}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule_cron

    lifecycle {
      delete_after = var.retention_days
    }
  }
}

resource "aws_backup_selection" "this" {
  name         = "${var.vault_name}-selection"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = data.aws_iam_role.this.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.selection_tag_key
    value = var.selection_tag_value
  }
}

# --- Notificações de job (sucesso/falha de backup e restore) ---

resource "aws_sns_topic" "this" {
  name = "${var.vault_name}-notifications"
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBackupServicePublish"
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.this.arn
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_backup_vault_notifications" "this" {
  backup_vault_name = aws_backup_vault.this.name
  sns_topic_arn     = aws_sns_topic.this.arn

  backup_vault_events = [
    "BACKUP_JOB_COMPLETED",
    "BACKUP_JOB_FAILED",
    "RESTORE_JOB_COMPLETED",
    "RESTORE_JOB_FAILED",
  ]

  depends_on = [aws_sns_topic_policy.this]
}

# --- Armazenamento do Velero (backup/restore do cluster EKS) ---
# Fica neste módulo por ser a mesma responsabilidade ("onde os backups moram"),
# mas a instalação em si (Helm release) é do module.velero.

resource "aws_s3_bucket" "velero" {
  bucket = var.velero_bucket_name
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }
}
