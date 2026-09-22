#
# Opção 2 pro bloqueio de IRSA/Pod Identity do CSI Driver (ver CLAUDE.md,
# seção "donation-service/ngo-service — bugs de ordenação de hook... e
# bloqueio de IRSA/Pod Identity"): o provider AWS do Secrets Store CSI Driver
# exige uma IAM role associada ao ServiceAccount (IRSA ou EKS Pod Identity)
# pra sincronizar o secret do AWS Secrets Manager pro pod — e nem IRSA (exige
# criar role nova, proibido na conta Academy) nem Pod Identity (a LabRole tem
# um deny explícito, numa policy própria da conta, pra editar a própria trust
# policy — confirmado rodando `aws iam update-assume-role-policy` de verdade)
# funcionam nesta conta.
#
# Este módulo sidesteps o CSI Driver por completo pro donation-service e
# ngo-service: em vez do POD puxar o segredo do Secrets Manager via CSI+IAM
# em runtime, o próprio Terraform (que já tem credenciais reais da sessão AWS
# Academy no momento do apply) escreve o Secret nativo do Kubernetes
# diretamente, usando os MESMOS valores que module.secrets já grava no AWS
# Secrets Manager (module.secrets continua existindo — não é redundante, é a
# cópia "oficial" no Secrets Manager pro relatório/demonstração de segurança
# do hackathon; este módulo é só o mecanismo de entrega pro cluster).
#
# Nome do Secret e das chaves batem exatamente com o que
# helm/{donation,ngo}-service/templates/deployment.yaml (repo gitops) espera
# via secretKeyRef — não requer NENHUMA mudança de código além de trocar
# awsSecrets (CSI) por externalSecret (Secret pré-existente, gerenciado por
# fora do Helm release) nos values.yaml desses 2 charts.
#
# Namespace criado aqui (não só pelo CreateNamespace=true do ArgoCD) porque
# um kubernetes_secret precisa que o namespace já exista no momento do
# apply — o `terraform apply` roda ANTES do primeiro sync do ArgoCD.
# Idempotente: quando o ArgoCD sincronizar depois com CreateNamespace=true,
# só vê que o namespace já existe e segue em frente, sem conflito.

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "donation_service" {
  metadata {
    name      = "donation-service-secret"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    DATABASE_URL = var.donation_database_url
    AWS_SQS_URL  = var.donation_sqs_queue_url
  }

  type = "Opaque"
}

resource "kubernetes_secret" "ngo_service" {
  metadata {
    name      = "ngo-service-secret"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    DATABASE_URL = var.ngo_database_url
  }

  type = "Opaque"
}
