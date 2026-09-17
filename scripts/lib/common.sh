#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de scripts/. Sempre sourced, nunca executado direto.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${ROOT_DIR}/iac/terraform"
BOOTSTRAP_DIR="${TF_DIR}/bootstrap-backend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

require_terraform() {
  command -v terraform >/dev/null 2>&1 || die "terraform não encontrado no PATH."
}

require_aws_cli() {
  command -v aws >/dev/null 2>&1 || die "aws CLI não encontrado no PATH."
}

# Valida o argumento de ambiente (dev|prd) e define ENV/TFVARS_FILE/BACKEND_FILE.
# Uso: require_env "$1"
require_env() {
  ENV="${1:-}"
  case "$ENV" in
    dev|prd) ;;
    *) die "Ambiente inválido: '${ENV}'. Uso: $(basename "$0") <dev|prd>" ;;
  esac
  TFVARS_FILE="terraform.${ENV}.tfvars"
  BACKEND_FILE="backends/${ENV}.tfbackend"
}

# Confere que a sessão de credenciais temporárias da AWS Academy (~4h) está
# válida antes de qualquer comando que fale com a AWS de verdade.
check_aws_session() {
  require_aws_cli
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    die "Sessão AWS Academy inválida/expirada. Reexporte as credenciais temporárias e tente de novo (aws sts get-caller-identity falhou)."
  fi
  log "Sessão AWS ativa: $(aws sts get-caller-identity --query Arn --output text)"
}

# Resolve as credenciais efetivas da sessão atual (env vars/profile já
# exportados pelo usuário a partir do AWS Academy) e injeta como TF_VAR_* —
# consumidas por var.aws_access_key_id/secret/session_token (module.secrets,
# ver iac/terraform/variable.tf). Nunca grava nada em disco.
export_tf_var_credentials() {
  require_aws_cli
  local creds
  creds="$(aws configure export-credentials --format env 2>/dev/null)" \
    || die "Não foi possível resolver credenciais AWS via 'aws configure export-credentials'. Confirme que a sessão Academy está exportada neste shell."
  eval "$creds"

  export TF_VAR_aws_access_key_id="${AWS_ACCESS_KEY_ID:?credencial AWS_ACCESS_KEY_ID vazia}"
  export TF_VAR_aws_secret_access_key="${AWS_SECRET_ACCESS_KEY:?credencial AWS_SECRET_ACCESS_KEY vazia}"
  export TF_VAR_aws_session_token="${AWS_SESSION_TOKEN:?credencial AWS_SESSION_TOKEN vazia}"
}
