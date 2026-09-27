output "cluster_autoscaler_release_name" {
  description = "Nome do release Helm do Cluster Autoscaler"
  value       = helm_release.cluster_autoscaler.name
}

output "cluster_autoscaler_release_namespace" {
  description = "Namespace onde o Cluster Autoscaler foi instalado"
  value       = helm_release.cluster_autoscaler.namespace
}

output "cluster_autoscaler_release_status" {
  description = "Status do release Helm do Cluster Autoscaler"
  value       = helm_release.cluster_autoscaler.status
}
