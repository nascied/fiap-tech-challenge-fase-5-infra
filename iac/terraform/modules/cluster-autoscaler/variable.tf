variable "cluster_name" {
  description = "Nome do cluster EKS (module.eks.aws_eks_cluster_name) — usado pelo autoDiscovery pra achar o Auto Scaling Group certo"
  type        = string
}

variable "namespace" {
  description = "Namespace onde o Cluster Autoscaler será instalado"
  type        = string
  default     = "kube-system"
}

variable "chart_version" {
  description = "Versão do chart Helm autoscaler/cluster-autoscaler — 9.59.0 tem appVersion 1.35.0, batendo exatamente com a versão do cluster EKS"
  type        = string
  default     = "9.59.0"
}

variable "aws_region" {
  description = "Região AWS do cluster/Auto Scaling Group"
  type        = string
  default     = "us-east-1"
}

variable "scale_down_enabled" {
  description = "Se false, o Cluster Autoscaler só escala pra cima (nunca remove nodes existentes) — útil pra evitar instabilidade antes de uma demo/gravação"
  type        = bool
  default     = true
}
