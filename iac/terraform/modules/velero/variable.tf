variable "namespace" {
  description = "Namespace onde o Velero será instalado"
  type        = string
  default     = "velero"
}

variable "chart_version" {
  description = "Versão do chart Helm vmware-tanzu/velero"
  type        = string
  default     = "8.1.0"
}

variable "bucket_name" {
  description = "Bucket S3 (module.backup.velero_bucket_name) onde o Velero grava os backups do cluster"
  type        = string
}

variable "aws_region" {
  description = "Região AWS do bucket S3 e dos snapshots de EBS"
  type        = string
  default     = "us-east-1"
}

variable "schedule_cron" {
  description = "Cron (formato padrão, não AWS) do backup agendado padrão do Velero"
  type        = string
  default     = "0 6 * * *" # 06:00 UTC = 03:00 America/Sao_Paulo
}

variable "backup_ttl" {
  description = "Tempo de retenção de cada backup agendado (formato Go duration, ex.: 168h = 7 dias)"
  type        = string
  default     = "168h"
}

variable "included_namespaces" {
  description = "Namespaces do cluster incluídos no backup agendado padrão"
  type        = list(string)
  default     = ["*"]
}
