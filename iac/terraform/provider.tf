provider "aws" {

  # Tags aplicadas automaticamente a TODO recurso AWS criado por este provider,
  # sem precisar declarar `tags` em cada resource individualmente — garante
  # 100% de cobertura das tags obrigatórias de FinOps exigidas no Hackathon
  # Fase 5. Ver README.md, seção "Estratégia de Tags", para o porquê de cada uma.
  default_tags {
    tags = {
      Project     = "SolidaryTech"
      Environment = var.environment
      CostCenter  = "NGO-Core"
      ManagedBy   = "Terraform"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.aws_eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.aws_eks_cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.aws_eks_cluster_name]
    }
  }
}