output "velero_release_name" {
  description = "Nome do release Helm do Velero"
  value       = helm_release.velero.name
}

output "velero_release_namespace" {
  description = "Namespace onde o Velero foi instalado"
  value       = helm_release.velero.namespace
}

output "velero_release_status" {
  description = "Status do release Helm do Velero"
  value       = helm_release.velero.status
}
