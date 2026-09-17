#!/usr/bin/env bash
# Orquestra o fluxo completo, na ordem: sessão -> backend -> init -> fmt/validate
# -> test -> plan -> apply (com confirmação, ver 06-apply.sh) -> kubeconfig.
#
# Uso: ./run-all.sh <dev|prd>
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

require_env "${1:-}"

"$DIR/00-check-session.sh"
"$DIR/01-bootstrap-backend.sh"
"$DIR/02-init.sh" "$ENV"
"$DIR/03-fmt-validate.sh"
"$DIR/04-test.sh"
"$DIR/05-plan.sh" "$ENV"
"$DIR/06-apply.sh" "$ENV"
"$DIR/07-update-kubeconfig.sh"

log "Fluxo completo concluído para o ambiente '${ENV}'."
