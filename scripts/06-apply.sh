#!/usr/bin/env bash
# Aplica o plano salvo por 05-plan.sh. Pede confirmação explícita — é uma ação
# real contra a conta AWS Academy, custo e recursos de verdade.
#
# Uso: ./06-apply.sh <dev|prd>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
require_env "${1:-}"
check_aws_session

cd "$TF_DIR"
[ -f tfplan ] || die "Nenhum tfplan encontrado em iac/terraform/. Rode 05-plan.sh ${ENV} antes."

warn "Isso vai aplicar o plano salvo (iac/terraform/tfplan) contra a conta AWS Academy — ambiente: ${ENV}."
read -r -p "Confirma o apply? [y/N] " CONFIRM
case "$CONFIRM" in
  y|Y) ;;
  *) die "Cancelado pelo usuário." ;;
esac

terraform apply tfplan
rm -f tfplan
log "Apply concluído. Se a infra criou/atualizou o EKS, rode 07-update-kubeconfig.sh em seguida."
