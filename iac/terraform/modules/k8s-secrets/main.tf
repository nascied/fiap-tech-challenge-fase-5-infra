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
# Namespace via resource condicional (count + data.kubernetes_all_namespaces),
# não null_resource/kubectl: o `fiap-tc-f5` pode já existir no cluster numa
# reaplicação (criado antes por um `kubectl apply -f argocd/root.yaml` do
# ArgoCD, fora do state do Terraform) — criar de novo sem essa checagem
# falharia com "already exists". `count` fica 0 quando o namespace já existe
# na lista retornada pelo data source, 1 quando precisa ser criado.
resource "kubernetes_namespace" "this" {
  count = contains(data.kubernetes_all_namespaces.this.namespaces, var.namespace) ? 0 : 1

  metadata {
    name = var.namespace
  }
}

# Os 2 Secrets usam var.namespace (string) direto, não um atributo do
# kubernetes_namespace.this — o nome do namespace já é conhecido de
# antemão independente de o Terraform tê-lo criado ou não (count 0 ou 1).
# depends_on garante a ordem (namespace antes do secret) mesmo quando
# count = 0 (referenciar o resource inteiro em depends_on é válido
# independente do count resolver pra 0 ou 1 instância).
resource "kubernetes_secret" "donation_service" {
  metadata {
    name      = "donation-service-secret"
    namespace = var.namespace
  }

  data = {
    DATABASE_URL = var.donation_database_url
    AWS_SQS_URL  = var.donation_sqs_queue_url
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.this]
}

resource "kubernetes_secret" "ngo_service" {
  metadata {
    name      = "ngo-service-secret"
    namespace = var.namespace
  }

  data = {
    DATABASE_URL = var.ngo_database_url
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.this]
}
