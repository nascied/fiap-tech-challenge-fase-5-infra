variable "vault_name" {
  type        = string
  description = "Nome do AWS Backup vault"
}

variable "schedule_cron" {
  type        = string
  description = "Expressão cron (formato AWS Backup) de agendamento do backup"
  default     = "cron(0 6 * * ? *)" # 06:00 UTC = 03:00 America/Sao_Paulo
}

variable "retention_days" {
  type        = number
  description = "Dias de retenção dos recovery points no vault"
  default     = 7
}

variable "selection_tag_key" {
  type        = string
  description = "Chave da tag usada para selecionar recursos a proteger"
  default     = "Backup"
}

variable "selection_tag_value" {
  type        = string
  description = "Valor da tag usada para selecionar recursos a proteger"
  default     = "true"
}

variable "notification_email" {
  type        = string
  description = "E-mail para notificação de falha/sucesso de backup e restore. Vazio desativa a inscrição SNS"
  default     = ""
}

variable "velero_bucket_name" {
  type        = string
  description = "Nome do bucket S3 usado pelo Velero para armazenar backups do cluster EKS"
}
