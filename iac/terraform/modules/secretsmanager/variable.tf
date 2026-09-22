variable "name_prefix" {
  description = "Prefixo dos nomes de secret (ex.: fiap-tc-f5)"
  type        = string
}

variable "aws_region" {
  type = string
}

# --- donation-service ---

variable "donation_database_url" {
  description = "Connection string do RDS do donation-service (module.db, índice do donation-service)"
  type        = string
  sensitive   = true
}

variable "donation_sqs_queue_url" {
  description = "URL da fila SQS usada pelo donation-service (module.sqs)"
  type        = string
}

# --- ngo-service ---
#
# ngo-service não usa credenciais AWS nem CSI Driver pra nada além disto: o
# único motivo dele ter um secret aqui é sincronizar o DATABASE_URL real do
# RDS (endpoint + senha compartilhada gerada por random_password.this) pro
# values.yaml do chart Helm sem passo manual — antes disso era um placeholder
# fixo (`CHANGE_ME`) sem nenhum mecanismo automatizado de atualização.

variable "ngo_database_url" {
  description = "Connection string do RDS do ngo-service (module.db, índice do ngo-service)"
  type        = string
  sensitive   = true
}
