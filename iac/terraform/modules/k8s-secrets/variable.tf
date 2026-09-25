variable "namespace" {
  description = "Namespace do Kubernetes onde os secrets são criados (mesmo namespace dos Deployments no repo gitops)"
  type        = string
}

variable "namespace_exists" {
  description = "Se var.namespace já existe no cluster (criado por uma apply anterior deste módulo, ou pelo CreateNamespace=true do ArgoCD) — controla o count de kubernetes_namespace.this. Precisa ser um bool simples, nunca derivado de um data source: um data source exige leitura em tempo de plan, e os providers kubernetes/helm só ficam configuráveis depois que module.eks existe de verdade, o que quebra plan num cluster novo (\"Invalid count argument\", ver CLAUDE.md). Resolvido automaticamente por scripts/05-plan.sh via TF_VAR_k8s_namespace_exists — default aqui é o fallback seguro (assume que não existe, e cria)."
  type        = bool
  default     = false
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
