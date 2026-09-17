#!/usr/bin/env bash
# Cria/atualiza o bucket S3 (fiap-tc-f5-iac) que guarda o state remoto do
# Terraform principal. Esse módulo é o único com state local de propósito —
# não dá pra guardar o próprio backend dentro do backend que ele cria.
# Idempotente: rodar de novo não recria o bucket se ele já existir.
#
# Uso: ./01-bootstrap-backend.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_terraform
check_aws_session

log "terraform init/apply em iac/terraform/bootstrap-backend"
cd "$BOOTSTRAP_DIR"
terraform init
terraform apply -auto-approve

log "Backend pronto. Bucket: $(terraform output -raw aws_s3_bucket_id 2>/dev/null || echo '(ver output acima)')"
