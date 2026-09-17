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

# --- credenciais AWS (Academy: sessão temporária STS, não IAM user permanente) ---
#
# Em conta AWS real, o caminho correto é IRSA (ver comentário no
# templates/serviceaccount.yaml de cada chart) — essas variáveis existem só
# porque a conta Academy não permite criar a IAM role que o IRSA exige, e o
# usuário optou por trazer credenciais explícitas via Secrets Manager mesmo
# assim, em vez de depender só do fallback de instance profile do node (LabRole)
# via IMDS, que também funcionaria e é o que module.velero já usa.
#
# São as MESMAS credenciais de sessão do `aws configure`/environment do
# Academy — temporárias (~4h). Precisam ser re-passadas (terraform apply de
# novo) toda vez que a sessão expirar; não há como isso ser permanente numa
# conta Academy.

variable "aws_access_key_id" {
  type      = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}

variable "aws_session_token" {
  type      = string
  sensitive = true
}
