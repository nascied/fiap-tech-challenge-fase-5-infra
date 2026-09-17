output "argocd_release_name" {
  description = "Nome do release Helm do ArgoCD"
  value       = helm_release.argocd.name
}

output "argocd_release_namespace" {
  description = "Namespace onde o ArgoCD foi instalado"
  value       = helm_release.argocd.namespace
}

output "argocd_release_status" {
  description = "Status do release Helm do ArgoCD"
  value       = helm_release.argocd.status
}
