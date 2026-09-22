variable "namespace" {
  description = "Namespace do Kubernetes onde os secrets são criados (mesmo namespace dos Deployments no repo gitops)"
  type        = string
}

variable "donation_database_url" {
  description = "Connection string do RDS do donation-service (module.db, índice do donation-service)"
  type        = string
  sensitive   = true
}

variable "donation_sqs_queue_url" {
  description = "URL da fila SQS usada pelo donation-service (module.sqs)"
  type        = string
}

variable "ngo_database_url" {
  description = "Connection string do RDS do ngo-service (module.db, índice do ngo-service)"
  type        = string
  sensitive   = true
}
