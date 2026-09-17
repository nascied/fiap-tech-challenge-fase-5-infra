#!/usr/bin/env bash
# terraform plan do ambiente escolhido, salvando o plano em iac/terraform/tfplan
# para o 06-apply.sh aplicar exatamente o que foi revisado aqui.
#
# Uso: ./05-plan.sh <dev|prd>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
require_env "${1:-}"
check_aws_session
export_tf_var_credentials

cd "$TF_DIR"
log "terraform plan (ambiente: ${ENV}, tfvars: ${TFVARS_FILE})"
terraform plan -var-file="${TFVARS_FILE}" -out=tfplan

log "Plano salvo em iac/terraform/tfplan — revise e rode 06-apply.sh ${ENV} para aplicar."
