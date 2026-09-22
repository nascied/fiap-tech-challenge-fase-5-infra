variable "aws_vpc" {
  description = "Configuração de rede AWS"
  type = object({
    name                     = string
    cidr_block               = string
    internet_gateway_name    = string
    nat_gateway_name         = string
    public_route_table_name  = string
    private_route_table_name = string
    public_subnets = list(object({
      name                    = string
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = bool
    }))
    private_subnets = list(object({
      name                    = string
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = bool
    }))
  })
}

variable "rds" {
  type = object({
    rds_properties = list(object({
      name    = string
      db_name = string
      db_user = string
    }))
  })
  sensitive = true
}

variable "aws_sqs_queue_name" {
  type = string
}

variable "aws_dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  type        = string
}

variable "aws_eks_cluster_version" {
  type = string
}

variable "aws_region" {
  description = "Região AWS onde a infra é provisionada — usada pelo module.velero (não altera o provider aws, que segue as credenciais ambiente/CLI)"
  type        = string
  default     = "us-east-1"
}

# --- FinOps: tagging (ver README.md, seção "Estratégia de Tags") ---

variable "environment" {
  description = "Ambiente da infra provisionada — vira a tag Environment em todos os recursos"
  type        = string
  default     = "Development"

  validation {
    condition     = contains(["Development", "Production"], var.environment)
    error_message = "environment deve ser \"Development\" ou \"Production\"."
  }
}

# --- DRP: AWS Backup (RDS + DynamoDB) ---

variable "backup_vault_name" {
  description = "Nome do AWS Backup vault"
  type        = string
  default     = "fiap-tc-f5-backup-vault"
}

variable "backup_schedule_cron" {
  description = "Expressão cron (formato AWS Backup) de agendamento do backup"
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "backup_retention_days" {
  description = "Dias de retenção dos recovery points no vault"
  type        = number
  default     = 7
}

variable "backup_notification_email" {
  description = "E-mail para notificação de falha/sucesso de backup e restore. Vazio desativa a inscrição SNS"
  type        = string
  default     = ""
}

# --- DRP: Velero (backup/restore do cluster EKS) ---

variable "velero_namespace" {
  description = "Namespace onde o Velero será instalado"
  type        = string
  default     = "velero"
}

variable "velero_chart_version" {
  description = "Versão do chart Helm vmware-tanzu/velero"
  type        = string
  default     = "8.1.0"
}

variable "velero_bucket_name" {
  description = "Nome do bucket S3 (globalmente único) onde o Velero grava os backups do cluster"
  type        = string
  default     = "fiap-tc-f5-velero-backups"
}

variable "velero_schedule_cron" {
  description = "Cron (formato padrão, não AWS) do backup agendado padrão do Velero"
  type        = string
  default     = "0 6 * * *"
}

variable "velero_included_namespaces" {
  description = "Namespaces do cluster incluídos no backup agendado padrão do Velero"
  type        = list(string)
  default     = ["*"]
}

# --- Secrets Manager (consumido via Secrets Store CSI Driver no cluster) ---
#
# donation-service e ngo-service leem DATABASE_URL daqui em vez de Secret do
# Kubernetes com valor literal no Helm values.yaml. Ver modules/secretsmanager
# e helm/{donation,ngo}-service/templates/secretproviderclass.yaml no repo
# GitOps.
#
# Sem variáveis de credencial AWS estática aqui (removidas numa sessão
# posterior): confirmado empiricamente, com um pod real no cluster sem
# ServiceAccount/CSI nenhum, que a cadeia padrão de credenciais do SDK já
# resolve sozinha via IMDS -> instance profile do node -> LabRole (mesmo
# caminho que module.velero já usa) — não há credencial de app pra popular
# no Secrets Manager.

# --- ITSM/AIOps: self-healing (module.incident_bridge, ver aiops/README.md) ---

variable "github_repo" {
  description = "Repositório GitHub (owner/repo) que recebe o repository_dispatch do incident-bridge"
  type        = string
  default     = "nascied/fiap-tech-challenge-fase-5-infra"
}

# Sensível, sem default de propósito — mesma lógica das credenciais AWS acima:
# nunca versionar em .tfvars, passar via TF_VAR_github_token no apply.
variable "github_token" {
  description = "Token do GitHub com permissão de repository_dispatch no repo acima (não versionar valor real)"
  type        = string
  sensitive   = true
}

variable "pagerduty_webhook_secret" {
  description = "Secret de verificação de assinatura da subscription de webhook V3 do PagerDuty (não versionar valor real)"
  type        = string
  sensitive   = true
}