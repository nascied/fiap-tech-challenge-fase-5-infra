variable "argocd_namespace" {
  description = "Namespace onde o ArgoCD será instalado"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Versão do chart argo-cd (repositório argoproj/argo-helm)"
  type        = string
  default     = "10.1.3"
}
