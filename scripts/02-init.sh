#!/usr/bin/env bash
# terraform init do módulo raiz, apontando pro backend S3 do ambiente escolhido.
#
# Uso: ./02-init.sh <dev|prd>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
require_env "${1:-}"

log "terraform init (ambiente: ${ENV}, backend: ${BACKEND_FILE})"
cd "$TF_DIR"
terraform init -reconfigure -backend-config="${BACKEND_FILE}"
