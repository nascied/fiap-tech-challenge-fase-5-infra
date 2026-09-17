locals {
  resource_prefix_name = "fiap-tc-f5"
  aws_eks_add_ons = [
    "kube-proxy",
    "coredns",
    "metrics-server",
    "external-dns",
    "vpc-cni",
    "eks-node-monitoring-agent",
    "eks-pod-identity-agent",
    "aws-ebs-csi-driver",
    # GA desde nov/2025 — já embute o Secrets Store CSI Driver (core) + provider
    # AWS num só add-on, sem precisar instalar via Helm separado. Usado por
    # donation-service e volunteer-service (SecretProviderClass) para ler
    # DATABASE_URL/credenciais AWS do Secrets Manager — ver module.secrets.
    "aws-secrets-store-csi-driver-provider"
  ]

  # Configuration values por add-on. O vpc-cni habilita prefix delegation para
  # elevar o limite de pods por node (t3.medium fica limitado a 17 pods/node sem isso).
  aws_eks_add_ons_configuration_values = {
    "vpc-cni" = jsonencode({
      env = {
        ENABLE_PREFIX_DELEGATION = "true"
        WARM_PREFIX_TARGET       = "1"
      }
    })
    # syncSecret.enabled: necessário para o padrão "secretObjects" nos
    # SecretProviderClass (sincroniza o valor lido do Secrets Manager para um
    # Secret nativo do Kubernetes, consumido via secretKeyRef normalmente).
    # Nota: há um bug conhecido (aws/secrets-store-csi-driver-provider-aws#597)
    # de configuration_values às vezes não propagar pro sub-chart bundlado —
    # se os Secrets não sincronizarem sozinhos, confirmar manualmente com
    # `kubectl get pods -n kube-system -l app=secrets-store-csi-driver -o yaml`
    # se o driver subiu com --enable-secret-rotation/sync habilitado.
    "aws-secrets-store-csi-driver-provider" = jsonencode({
      secrets-store-csi-driver = {
        syncSecret = {
          enabled = true
        }
      }
    })
  }
}