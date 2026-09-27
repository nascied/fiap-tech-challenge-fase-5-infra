#!/usr/bin/env bash
# Destrói os recursos criados por dr-test-restore-data.sh: instâncias RDS
# restauradas, tabela DynamoDB importada, bucket S3 de export, security
# group/DB subnet group, e os snapshots manuais (origem + destino). Ação
# real e irreversível — dupla confirmação, mesmo espírito do 08-destroy.sh.
#
# Uso: ./dr-test-destroy-data.sh [regiao-destino] [regiao-origem]
#   regiao-destino (opcional, default: us-west-2)
#   regiao-origem  (opcional, default: us-east-1 — só os SNAPSHOTS de lá são
#                  removidos; o RDS/DynamoDB de produção nunca é tocado)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_aws_cli
check_aws_session

DST_REGION="${1:-us-west-2}"
SRC_REGION="${2:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

RDS_INSTANCES=(donation-service-dr-test ngo-service-dr-test)
DYNAMO_TABLE="SolidaryTechVolunteers"
EXPORT_BUCKET="fiap-tc-f5-dr-test-dynamodb-export-${ACCOUNT_ID}"
SG_NAME="fiap-tc-f5-dr-test-rds-sg"
SUBNET_GROUP_NAME="fiap-tc-f5-dr-test-subnet-group"

warn "Isso vai DESTRUIR de vez: RDS ${RDS_INSTANCES[*]} (${DST_REGION}), tabela DynamoDB '${DYNAMO_TABLE}' (${DST_REGION}), bucket '${EXPORT_BUCKET}', SG/subnet group, e os snapshots manuais 'donation-service-dr-*'/'ngo-service-dr-*' em ${DST_REGION} E ${SRC_REGION}. Produção (RDS/DynamoDB reais) NÃO é tocada."
read -r -p "Digite 'destruir-dados-dr' para confirmar: " CONFIRM
[ "$CONFIRM" = "destruir-dados-dr" ] || die "Confirmação não bateu. Cancelado."

# --- RDS ---
for id in "${RDS_INSTANCES[@]}"; do
  if aws rds describe-db-instances --region "$DST_REGION" --db-instance-identifier "$id" >/dev/null 2>&1; then
    log "Deletando instância RDS '${id}'..."
    aws rds delete-db-instance --region "$DST_REGION" --db-instance-identifier "$id" \
      --skip-final-snapshot --delete-automated-backups >/dev/null
  else
    log "Instância RDS '${id}' não existe — pulando."
  fi
done
for id in "${RDS_INSTANCES[@]}"; do
  if aws rds describe-db-instances --region "$DST_REGION" --db-instance-identifier "$id" >/dev/null 2>&1; then
    log "Aguardando exclusão de '${id}'..."
    aws rds wait db-instance-deleted --region "$DST_REGION" --db-instance-identifier "$id"
  fi
done

# --- DynamoDB ---
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$DST_REGION" >/dev/null 2>&1; then
  log "Deletando tabela DynamoDB '${DYNAMO_TABLE}' em ${DST_REGION}..."
  aws dynamodb delete-table --table-name "$DYNAMO_TABLE" --region "$DST_REGION" >/dev/null
  aws dynamodb wait table-not-exists --table-name "$DYNAMO_TABLE" --region "$DST_REGION"
fi

# --- Bucket de export ---
if aws s3api head-bucket --bucket "$EXPORT_BUCKET" --region "$DST_REGION" 2>/dev/null; then
  log "Esvaziando e deletando bucket '${EXPORT_BUCKET}'..."
  aws s3 rm "s3://${EXPORT_BUCKET}" --recursive --region "$DST_REGION" >/dev/null
  aws s3api delete-bucket --bucket "$EXPORT_BUCKET" --region "$DST_REGION"
fi

# --- Security group + DB subnet group ---
VPC_FILTER_SG_ID="$(aws ec2 describe-security-groups --region "$DST_REGION" --filters "Name=group-name,Values=${SG_NAME}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [ -n "$VPC_FILTER_SG_ID" ] && [ "$VPC_FILTER_SG_ID" != "None" ]; then
  log "Deletando security group '${SG_NAME}' (${VPC_FILTER_SG_ID})..."
  aws ec2 delete-security-group --region "$DST_REGION" --group-id "$VPC_FILTER_SG_ID" || warn "Não deu pra deletar o SG agora (pode ainda estar em uso) — tente de novo em alguns minutos."
fi

if aws rds describe-db-subnet-groups --region "$DST_REGION" --db-subnet-group-name "$SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  log "Deletando DB subnet group '${SUBNET_GROUP_NAME}'..."
  aws rds delete-db-subnet-group --region "$DST_REGION" --db-subnet-group-name "$SUBNET_GROUP_NAME"
fi

# --- Snapshots manuais (origem + destino) ---
for region in "$DST_REGION" "$SRC_REGION"; do
  mapfile -t SNAPSHOTS < <(aws rds describe-db-snapshots --region "$region" --snapshot-type manual \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, 'donation-service-dr-') || starts_with(DBSnapshotIdentifier, 'ngo-service-dr-')].DBSnapshotIdentifier" \
    --output text | tr '\t' '\n')
  for snap in "${SNAPSHOTS[@]}"; do
    [ -z "$snap" ] && continue
    log "Deletando snapshot '${snap}' em ${region}..."
    aws rds delete-db-snapshot --region "$region" --db-snapshot-identifier "$snap" >/dev/null
  done
done

log "Limpeza da camada de dados concluída. Produção (${SRC_REGION}) não foi tocada."
