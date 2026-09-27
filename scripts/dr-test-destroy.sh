#!/usr/bin/env bash
# Destrói o cluster de teste de DR criado por dr-test-create.sh (eksctl, fora
# do Terraform/state principal). Ação real e dificilmente reversível — dupla
# confirmação, mesmo espírito do 08-destroy.sh.
#
# Uso: ./dr-test-destroy.sh [regiao] [nome-cluster]
#   regiao       (opcional, default: us-west-2)
#   nome-cluster (opcional, default: fiap-tc-f5-dr-test)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_aws_cli
check_aws_session
command -v eksctl >/dev/null 2>&1 || die "eksctl não encontrado no PATH."

DR_REGION="${1:-us-west-2}"
DR_CLUSTER="${2:-fiap-tc-f5-dr-test}"

warn "Isso vai DESTRUIR o cluster de teste de DR '${DR_CLUSTER}' em '${DR_REGION}' (VPC, node group, addons) — ação real, sem desfazer."
read -r -p "Digite o nome do cluster (${DR_CLUSTER}) para confirmar: " CONFIRM_NAME
[ "$CONFIRM_NAME" = "$DR_CLUSTER" ] || die "Confirmação não bateu. Cancelado."

log "Destruindo cluster '${DR_CLUSTER}' em '${DR_REGION}'..."
eksctl delete cluster --name "${DR_CLUSTER}" --region "${DR_REGION}"

log "Cluster de teste de DR destruído. O bucket de produção (fonte dos backups) não foi tocado."
