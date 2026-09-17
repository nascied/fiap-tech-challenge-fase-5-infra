output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID da VPC"
}

output "internet_gateway_id" {
  value       = module.vpc.internet_gateway_id
  description = "ID do internet gateway"
}

output "public_subnet_arns" {
  value       = module.vpc.public_subnet_arns
  description = "ARN das subnets publicas"
}

output "private_subnet_arns" {
  value       = module.vpc.private_subnet_arns
  description = "ARN das subnets privadas"
}

output "private_subnet_id" {
  value       = module.vpc.private_subnet_id
  description = "Ids das subnets privadas"
}

output "public_subnet_id" {
  value       = module.vpc.public_subnet_id
  description = "Ids das subnetes publicas"
}

#----------------------------------------
# Output RDS database
#----------------------------------------

output "aws_db_instance_endpoint" {
  description = "RDS endpoint"
  value       = module.db.aws_db_instance_endpoint
}

output "aws_db_instance_hostname" {
  description = "RDS hostname"
  value       = module.db.aws_db_instance_hostname
}

output "aws_db_instance_port" {
  description = "RDS port"
  value       = module.db.aws_db_instance_port
}

output "aws_db_instance_name" {
  description = "Database name"
  value       = module.db.aws_db_instance_name
  sensitive   = true
}

output "aws_db_instance_master_user" {
  description = "Master username"
  value       = module.db.aws_db_instance_master_user
  sensitive   = true
}

output "aws_db_instance_connection_strings" {
  description = "PostgreSQL connection string"
  value       = module.db.aws_db_instance_connection_strings
  sensitive   = true
}

#----------------------------------------
# Output cluster eks
#----------------------------------------

output "aws_eks_cluster_id" {
  value       = module.eks.aws_eks_cluster_id
  description = "Id do clueste EKS"
}

output "aws_eks_cluster_arn" {
  value       = module.eks.aws_eks_cluster_arn
  description = "ARN do cluster EKS"
}

output "aws_eks_cluster_endpoint" {
  value       = module.eks.aws_eks_cluster_endpoint
  description = "Endereço do endpoint do cluster EKS"
}

output "aws_eks_cluster_platform_version" {
  value       = module.eks.aws_eks_cluster_platform_version
  description = "Versão do cluster EKS"
}

output "aws_eks_cluster_security_group_id" {
  value       = module.eks.aws_eks_cluster_security_group_id
  description = "Security group do cluster EKS (control plane e node group)"
}

output "aws_eks_cluster_name" {
  value       = module.eks.aws_eks_cluster_name
  description = "Nome do cluster EKS"
}

output "aws_eks_cluster_certificate_authority_data" {
  value       = module.eks.aws_eks_cluster_certificate_authority_data
  description = "Certificado da autoridade certificadora do cluster EKS (base64)"
  sensitive   = true
}

#---------------------------------------
# Output do registry
#---------------------------------------

output "aws_ecr_repository_arn" {
  value       = module.ecr.aws_ecr_repository_arn
  description = "ARN no registry de imagem"
}

output "aws_ecr_repository_registry_id" {
  value       = module.ecr.aws_ecr_repository_registry_id
  description = "Id do registry de imagem"
}

output "aws_ecr_repository_repository_url" {
  value       = module.ecr.aws_ecr_repository_repository_url
  description = "URL do registry de imagem"
}

#---------------------
# SQS outputs
#---------------------

output "sqs_queue_url" {
  description = "URL da fila SQS"
  value       = module.sqs.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS"
  value       = module.sqs.sqs_queue_arn
}

output "sqs_queue_name" {
  description = "Nome da fila SQS"
  value       = module.sqs.sqs_queue_name
}

#----------------------------
# DynamoDB
#----------------------------

output "aws_dynamodb_table_name" {
  value       = module.dynamodb.aws_dynamodb_table_name
  description = "Nome da tabela DynamoDB"
}

output "aws_dynamodb_table_arn" {
  value       = module.dynamodb.aws_dynamodb_table_arn
  description = "ARN da tabela DynamoDB"
}

output "aws_dynamodb_table_id" {
  value       = module.dynamodb.aws_dynamodb_table_id
  description = "ID da tabela DynamoDB"
}

#----------------------------
# ArgoCD
#----------------------------

output "argocd_release_name" {
  value       = module.argocd.argocd_release_name
  description = "Nome do release Helm do ArgoCD"
}

output "argocd_release_namespace" {
  value       = module.argocd.argocd_release_namespace
  description = "Namespace onde o ArgoCD foi instalado"
}

output "argocd_release_status" {
  value       = module.argocd.argocd_release_status
  description = "Status do release Helm do ArgoCD"
}

#----------------------------
# DRP: AWS Backup
#----------------------------

output "backup_vault_arn" {
  value       = module.backup.backup_vault_arn
  description = "ARN do AWS Backup vault"
}

output "backup_plan_id" {
  value       = module.backup.backup_plan_id
  description = "ID do plano de backup"
}

output "backup_sns_topic_arn" {
  value       = module.backup.sns_topic_arn
  description = "ARN do tópico SNS de notificação de jobs de backup/restore"
}

#----------------------------
# DRP: Velero
#----------------------------

output "velero_bucket_name" {
  value       = module.backup.velero_bucket_name
  description = "Bucket S3 usado pelo Velero para backups do cluster EKS"
}

output "velero_release_status" {
  value       = module.velero.velero_release_status
  description = "Status do release Helm do Velero"
}

#----------------------------
# Secrets Manager (CSI Driver)
#----------------------------

output "donation_service_secret_name" {
  value       = module.secrets.donation_service_secret_name
  description = "Nome do secret do donation-service no Secrets Manager (objectName do SecretProviderClass)"
}

output "volunteer_service_secret_name" {
  value       = module.secrets.volunteer_service_secret_name
  description = "Nome do secret do volunteer-service no Secrets Manager (objectName do SecretProviderClass)"
}

output "ngo_service_secret_name" {
  value       = module.secrets.ngo_service_secret_name
  description = "Nome do secret do ngo-service no Secrets Manager (objectName do SecretProviderClass)"
}

#----------------------------
# ITSM/AIOps: self-healing (incident-bridge)
#----------------------------

output "incident_bridge_function_url" {
  value       = module.incident_bridge.function_url
  description = "URL pública da Lambda-ponte — configurar como destino da webhook subscription V3 no PagerDuty"
}
