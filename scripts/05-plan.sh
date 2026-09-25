#!/usr/bin/env bash
# terraform plan do ambiente escolhido, salvando o plano em iac/terraform/tfplan
# para o 06-apply.sh aplicar exatamente o que foi revisado aqui.
#
# Uso: ./05-plan.sh <dev|prd>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
require_env "${1:-}"
check_aws_session

cd "$TF_DIR"

# module.k8s_secrets controla a criação do namespace "fiap-tc-f5" via
# var.k8s_namespace_exists (bool simples — ver modules/k8s-secrets/variable.tf
# pro porquê de não ser mais um data source: um data source quebrava
# "terraform plan" com "Invalid count argument" num cluster novo, já que os
# providers kubernetes/helm só ficam configuráveis depois que module.eks
# existe de verdade). Detectamos aqui, FORA do Terraform, se o namespace já
# existe, e exportamos como TF_VAR_k8s_namespace_exists antes do plan — assim
# ninguém precisa lembrar de virar essa flag manualmente a cada apply
# (exatamente o problema que a versão anterior, com data source, evitava).
#
# Lógica: se ainda não há cluster no output (primeiro apply) ou o kubeconfig
# não resolve por qualquer motivo, assume "false" (fallback seguro — pior
# caso, tenta criar um namespace que já existe e falha com "already exists",
# um erro real e óbvio, não mais um "Invalid count argument" enigmático).
# Pode ser sobrescrito manualmente exportando TF_VAR_k8s_namespace_exists
# antes de rodar este script.
if [ -z "${TF_VAR_k8s_namespace_exists:-}" ]; then
  NAMESPACE_EXISTS="false"
  CLUSTER_NAME="$(terraform output -raw aws_eks_cluster_name 2>/dev/null || true)"
  if [ -n "$CLUSTER_NAME" ] && command -v kubectl >/dev/null 2>&1; then
    if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "${AWS_REGION:-us-east-1}" >/dev/null 2>&1; then
      if kubectl get namespace fiap-tc-f5 >/dev/null 2>&1; then
        NAMESPACE_EXISTS="true"
      fi
    fi
  fi
  export TF_VAR_k8s_namespace_exists="$NAMESPACE_EXISTS"
fi
log "namespace fiap-tc-f5 já existe? TF_VAR_k8s_namespace_exists=${TF_VAR_k8s_namespace_exists}"

log "terraform plan (ambiente: ${ENV}, tfvars: ${TFVARS_FILE})"
terraform plan -var-file="${TFVARS_FILE}" -out=tfplan

log "Plano salvo em iac/terraform/tfplan — revise e rode 06-apply.sh ${ENV} para aplicar."
