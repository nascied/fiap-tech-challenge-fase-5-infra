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
#
# O recurso nativo `aws_s3_bucket` não funciona nesta conta: mesmo criando o
# bucket sem nenhuma configuração extra, o provider AWS faz um Read logo
# depois do Create pra popular o state inteiro — inclusive uma chamada
# GetBucketObjectLockConfiguration — e a SCP da conta AWS Academy nega essa
# chamada explicitamente, em toda a organização (mesmo bug já corrigido em
# bootstrap-backend/main.tf). Criar o bucket via CLI (`aws s3api
# create-bucket`) num `null_resource` evita esse Read por completo. Os 3
# recursos de configuração abaixo (versioning/public-access-block/lifecycle)
# são tipos separados, com Read próprio que não toca Object Lock — continuam
# nativos, só passam a referenciar `var.velero_bucket_name` (string) em vez de
# um atributo do recurso removido, com `depends_on` explícito pra manter a
# ordem de criação.
resource "null_resource" "velero_bucket" {
  triggers = {
    bucket_name = var.velero_bucket_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      if aws s3api head-bucket --bucket "${self.triggers.bucket_name}" 2>/dev/null; then
        echo "Bucket ${self.triggers.bucket_name} já existe, nada a fazer."
      else
        aws s3api create-bucket --bucket "${self.triggers.bucket_name}"
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rb \"s3://${self.triggers.bucket_name}\" --force || true"
  }
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = var.velero_bucket_name

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [null_resource.velero_bucket]
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = var.velero_bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [null_resource.velero_bucket]
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = var.velero_bucket_name

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

  depends_on = [null_resource.velero_bucket, aws_s3_bucket_versioning.velero]
}
