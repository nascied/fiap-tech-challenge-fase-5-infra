#!/usr/bin/env bash
# Destrói toda a infra do ambiente escolhido. Ação destrutiva e dificilmente
# reversível — exige dupla confirmação (nome do ambiente + revisão do plano).
#
# Uso: ./08-destroy.sh <dev|prd>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
require_env "${1:-}"
check_aws_session
export_tf_var_credentials

cd "$TF_DIR"

warn "Isso vai DESTRUIR toda a infra Terraform do ambiente '${ENV}' na conta AWS Academy."
read -r -p "Digite o nome do ambiente (${ENV}) para confirmar: " CONFIRM_ENV
[ "$CONFIRM_ENV" = "$ENV" ] || die "Confirmação não bateu com '${ENV}'. Cancelado."

terraform plan -destroy -var-file="${TFVARS_FILE}" -out=tfplan-destroy

warn "Revise o plano de destroy acima com atenção."
read -r -p "Confirma o destroy? [y/N] " CONFIRM
case "$CONFIRM" in
  y|Y) ;;
  *) rm -f tfplan-destroy; die "Cancelado pelo usuário." ;;
esac

terraform apply tfplan-destroy
rm -f tfplan-destroy
log "Destroy concluído (ambiente: ${ENV})."
