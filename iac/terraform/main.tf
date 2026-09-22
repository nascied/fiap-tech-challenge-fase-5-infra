resource "random_password" "this" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

  lifecycle {
    ignore_changes = [
      length,
      lower,
    ]
  }

}

module "vpc" {
  source = "./modules/vpc"

  aws_vpc = var.aws_vpc

}

module "eks" {
  source = "./modules/eks"

  aws_subnet_public_ids   = module.vpc.public_subnet_id
  aws_subnet_private_ids  = module.vpc.private_subnet_id
  aws_eks_cluster_version = var.aws_eks_cluster_version

  depends_on = [module.vpc]
}

module "db" {
  source = "./modules/rds"

  rds                        = var.rds
  rds_db_pass                = random_password.this.result
  aws_subnet_ids             = module.vpc.private_subnet_id
  aws_db_subnet_group_vpc_id = module.vpc.vpc_id
  eks_security_group_id      = module.eks.aws_eks_cluster_security_group_id

  depends_on = [module.vpc, module.eks]
}

module "ecr" {
  source = "./modules/ecr"

  depends_on = [module.eks]
}

module "backup" {
  source = "./modules/backup"

  vault_name         = var.backup_vault_name
  schedule_cron      = var.backup_schedule_cron
  retention_days     = var.backup_retention_days
  notification_email = var.backup_notification_email
  velero_bucket_name = var.velero_bucket_name

  depends_on = [module.db, module.dynamodb]
}

module "velero" {
  source = "./modules/velero"

  namespace           = var.velero_namespace
  chart_version       = var.velero_chart_version
  bucket_name         = module.backup.velero_bucket_name
  aws_region          = var.aws_region
  schedule_cron       = var.velero_schedule_cron
  included_namespaces = var.velero_included_namespaces

  depends_on = [module.eks, module.backup]
}

module "sqs" {
  source = "./modules/sqs"

  aws_sqs_queue_name = var.aws_sqs_queue_name

  depends_on = [module.vpc]
}

# module "cache" (./modules/redis) removida do provisionamento: nenhum dos 3
# microsserviços (ngo-service, donation-service, volunteer-service) usa Redis
# — era resíduo do projeto anterior. Ver docs/finops/FORECAST.md. O módulo
# continua em modules/redis/ (código preservado, só não é mais instanciado).

module "dynamodb" {
  source = "./modules/dynamodb"

  aws_dynamodb_table_name = var.aws_dynamodb_table_name

  depends_on = [module.vpc]
}

module "argocd" {
  source = "./modules/argocd"

  depends_on = [module.eks]
}

module "secrets" {
  source = "./modules/secretsmanager"

  name_prefix = "fiap-tc-f5"
  aws_region  = var.aws_region

  # var.rds.rds_properties[0] = donation-service, [1] = ngo-service (ver terraform.{dev,prd}.tfvars)
  donation_database_url  = module.db.aws_db_instance_connection_strings[0]
  donation_sqs_queue_url = module.sqs.sqs_queue_url
  ngo_database_url       = module.db.aws_db_instance_connection_strings[1]

  depends_on = [module.db, module.sqs]
}

# Opção 2 pro bloqueio de IRSA/Pod Identity do CSI Driver (donation-service/
# ngo-service não conseguem sincronizar o secret via Secrets Store CSI Driver
# nesta conta — ver comentário completo em modules/k8s-secrets/main.tf e
# CLAUDE.md). Escreve o mesmo DATABASE_URL/AWS_SQS_URL diretamente como
# Secret nativo do Kubernetes, sem depender de IAM role associada a
# ServiceAccount nenhuma.
module "k8s_secrets" {
  source = "./modules/k8s-secrets"

  namespace = "fiap-tc-f5"

  donation_database_url  = module.db.aws_db_instance_connection_strings[0]
  donation_sqs_queue_url = module.sqs.sqs_queue_url
  ngo_database_url       = module.db.aws_db_instance_connection_strings[1]

  depends_on = [module.eks, module.db, module.sqs]
}

# ITSM/AIOps: self-healing de incidentes (ver aiops/README.md na raiz do
# repo). Única peça de infra nova do fluxo PagerDuty -> Lambda -> GitHub
# Actions -> Claude com tool-use -> kubectl rollout restart.
module "incident_bridge" {
  source = "./modules/lambda"

  github_repo              = var.github_repo
  github_token             = var.github_token
  pagerduty_webhook_secret = var.pagerduty_webhook_secret
}