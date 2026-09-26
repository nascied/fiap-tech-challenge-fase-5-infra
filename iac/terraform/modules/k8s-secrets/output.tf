output "namespace" {
  description = "Namespace onde os secrets foram criados"
  value       = var.namespace
  depends_on  = [kubernetes_namespace.this]
}

output "donation_service_secret_name" {
  description = "Nome do Secret nativo do Kubernetes com DATABASE_URL/AWS_SQS_URL do donation-service"
  value       = kubernetes_secret.donation_service.metadata[0].name
}

output "ngo_service_secret_name" {
  description = "Nome do Secret nativo do Kubernetes com DATABASE_URL do ngo-service"
  value       = kubernetes_secret.ngo_service.metadata[0].name
}
