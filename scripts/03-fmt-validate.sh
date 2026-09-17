#!/usr/bin/env bash
# fmt + validate (+ tflint, se instalado) — não toca a AWS de verdade, pode
# rodar mesmo com a sessão Academy expirada.
#
# Uso: ./03-fmt-validate.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
cd "$TF_DIR"

log "terraform fmt -check -recursive"
terraform fmt -check -recursive

log "terraform validate"
terraform validate

if command -v tflint >/dev/null 2>&1; then
  log "tflint"
  tflint --init
  tflint --recursive
else
  warn "tflint não encontrado no PATH — pulando lint estático (o workflow de CI roda isso também, ver .github/workflows/terraform.yml)."
fi
