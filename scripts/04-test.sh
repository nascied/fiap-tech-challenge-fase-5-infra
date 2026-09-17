#!/usr/bin/env bash
# terraform test contra iac.tftest.hcl — usa mock_provider, não toca a AWS
# de verdade. Pode rodar mesmo com a sessão Academy expirada.
#
# Uso: ./04-test.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
cd "$TF_DIR"

log "terraform test (mock_provider)"
terraform test
