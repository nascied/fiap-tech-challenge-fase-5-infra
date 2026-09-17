#!/usr/bin/env bash
# Configura o kubeconfig local para o cluster EKS criado pelo module.eks e
# confirma acesso (kubectl get nodes). Lê o nome do cluster direto do state
# via terraform output — não precisa passar nada na mão.
#
# Uso: ./07-update-kubeconfig.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
require_aws_cli
command -v kubectl >/dev/null 2>&1 || die "kubectl não encontrado no PATH."

cd "$TF_DIR"
CLUSTER_NAME="$(terraform output -raw aws_eks_cluster_name 2>/dev/null)" \
  || die "Não consegui ler aws_eks_cluster_name do state. O cluster já foi criado (rodou 05-plan.sh + 06-apply.sh)?"

log "Atualizando kubeconfig para o cluster '${CLUSTER_NAME}' (us-east-1)"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1

log "Testando acesso ao cluster..."
kubectl get nodes
