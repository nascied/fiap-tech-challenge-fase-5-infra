#!/usr/bin/env bash
# Restaura a camada de DADOS (RDS + DynamoDB) na região do cluster de teste de
# DR criado por dr-test-create.sh — fecha a limitação documentada nesse script
# ("donation-service/ngo-service não ficam saudáveis aqui sem tratar a camada
# de dados à parte"). Encapsula o fluxo validado manualmente contra a AWS
# Academy real: RDS via snapshot->copy cross-region->restore (não existe
# alternativa mais simples — PITR nativo do RDS é same-region); DynamoDB via
# export point-in-time->import cross-region (mesma razão: restore-table-to-
# point-in-time também é same-region; cross-region de verdade exigiria Global
# Tables, não configurado neste projeto).
#
# Uso: ./dr-test-restore-data.sh [regiao-destino] [regiao-origem] [nome-cluster]
#   regiao-destino (opcional, default: us-west-2 — onde restaurar)
#   regiao-origem  (opcional, default: us-east-1 — produção real)
#   nome-cluster   (opcional, default: fiap-tc-f5-dr-test — usado só pra
#                  descobrir a VPC/subnets onde o RDS deve nascer)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_aws_cli
check_aws_session
command -v python3 >/dev/null 2>&1 || die "python3 não encontrado no PATH."

DST_REGION="${1:-us-west-2}"
SRC_REGION="${2:-us-east-1}"
DR_CLUSTER="${3:-fiap-tc-f5-dr-test}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TS="$(date +%Y%m%d%H%M%S)"

RDS_INSTANCES=(donation-service ngo-service)
DYNAMO_TABLE="SolidaryTechVolunteers"
EXPORT_BUCKET="fiap-tc-f5-dr-test-dynamodb-export-${ACCOUNT_ID}"
SG_NAME="fiap-tc-f5-dr-test-rds-sg"
SUBNET_GROUP_NAME="fiap-tc-f5-dr-test-subnet-group"

warn "Isso cria recursos REAIS em '${DST_REGION}' (2 instâncias RDS db.t3.micro, 1 tabela DynamoDB, 1 bucket S3, snapshots em ambas as regiões) — custo real, ~15-20min no total."
read -r -p "Confirma? [y/N] " CONFIRM
case "$CONFIRM" in
  y|Y) ;;
  *) die "Cancelado pelo usuário." ;;
esac

wait_rds_snapshot() {
  aws rds wait db-snapshot-available --region "$1" --db-snapshot-identifier "$2"
}
wait_rds_instance() {
  aws rds wait db-instance-available --region "$1" --db-instance-identifier "$2"
}

# --- 1. Snapshot manual de cada instância RDS (região de origem) ---
for id in "${RDS_INSTANCES[@]}"; do
  log "Criando snapshot de '${id}' em ${SRC_REGION}..."
  aws rds create-db-snapshot --region "$SRC_REGION" \
    --db-instance-identifier "$id" \
    --db-snapshot-identifier "${id}-dr-${TS}" \
    --tags Key=Purpose,Value=cross-region-dr-test >/dev/null
done
for id in "${RDS_INSTANCES[@]}"; do
  log "Aguardando snapshot de '${id}'..."
  wait_rds_snapshot "$SRC_REGION" "${id}-dr-${TS}"
done

# --- 2. Cópia cross-region dos snapshots ---
for id in "${RDS_INSTANCES[@]}"; do
  log "Copiando snapshot de '${id}' para ${DST_REGION}..."
  aws rds copy-db-snapshot --region "$DST_REGION" --source-region "$SRC_REGION" \
    --source-db-snapshot-identifier "arn:aws:rds:${SRC_REGION}:${ACCOUNT_ID}:snapshot:${id}-dr-${TS}" \
    --target-db-snapshot-identifier "${id}-dr-${TS}" \
    --tags Key=Purpose,Value=cross-region-dr-test >/dev/null
done
for id in "${RDS_INSTANCES[@]}"; do
  log "Aguardando cópia de '${id}' em ${DST_REGION}..."
  wait_rds_snapshot "$DST_REGION" "${id}-dr-${TS}"
done

# --- 3. Rede: SG + DB subnet group na VPC do cluster de DR (idempotente) ---
log "Descobrindo VPC/subnets do cluster '${DR_CLUSTER}' em ${DST_REGION}..."
VPC_ID="$(aws eks describe-cluster --name "$DR_CLUSTER" --region "$DST_REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
VPC_CIDR="$(aws ec2 describe-vpcs --region "$DST_REGION" --vpc-ids "$VPC_ID" --query 'Vpcs[0].CidrBlock' --output text)"
mapfile -t ALL_SUBNETS < <(aws eks describe-cluster --name "$DR_CLUSTER" --region "$DST_REGION" --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' '\n')
mapfile -t PRIVATE_SUBNETS < <(aws ec2 describe-subnets --region "$DST_REGION" --subnet-ids "${ALL_SUBNETS[@]}" \
  --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' --output text | tr '\t' '\n')
[ "${#PRIVATE_SUBNETS[@]}" -ge 2 ] || die "Menos de 2 subnets privadas encontradas na VPC ${VPC_ID} — não dá pra criar um DB subnet group válido (RDS exige >= 2 AZs)."

SG_ID="$(aws ec2 describe-security-groups --region "$DST_REGION" --filters "Name=group-name,Values=${SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
  log "Criando security group '${SG_NAME}'..."
  SG_ID="$(aws ec2 create-security-group --region "$DST_REGION" --group-name "$SG_NAME" \
    --description "SG temporario para RDS restaurado no teste de DR cross-region" --vpc-id "$VPC_ID" --query 'GroupId' --output text)"
  aws ec2 authorize-security-group-ingress --region "$DST_REGION" --group-id "$SG_ID" --protocol tcp --port 5432 --cidr "$VPC_CIDR" >/dev/null
else
  log "Security group '${SG_NAME}' já existe (${SG_ID}) — reaproveitando."
fi

if ! aws rds describe-db-subnet-groups --region "$DST_REGION" --db-subnet-group-name "$SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  log "Criando DB subnet group '${SUBNET_GROUP_NAME}'..."
  aws rds create-db-subnet-group --region "$DST_REGION" \
    --db-subnet-group-name "$SUBNET_GROUP_NAME" \
    --db-subnet-group-description "Subnets privadas do cluster de DR (${DR_CLUSTER}) para restore cross-region" \
    --subnet-ids "${PRIVATE_SUBNETS[@]}" >/dev/null
else
  log "DB subnet group '${SUBNET_GROUP_NAME}' já existe — reaproveitando."
fi

# --- 4. Restore de cada instância RDS na região de destino ---
for id in "${RDS_INSTANCES[@]}"; do
  log "Restaurando '${id}-dr-test' em ${DST_REGION}..."
  aws rds restore-db-instance-from-db-snapshot --region "$DST_REGION" \
    --db-instance-identifier "${id}-dr-test" \
    --db-snapshot-identifier "${id}-dr-${TS}" \
    --db-instance-class db.t3.micro \
    --db-subnet-group-name "$SUBNET_GROUP_NAME" \
    --vpc-security-group-ids "$SG_ID" \
    --no-multi-az --no-publicly-accessible \
    --tags Key=Purpose,Value=cross-region-dr-test >/dev/null
done
for id in "${RDS_INSTANCES[@]}"; do
  log "Aguardando restore de '${id}-dr-test'..."
  wait_rds_instance "$DST_REGION" "${id}-dr-test"
done

log "RDS restaurado. Endpoints:"
for id in "${RDS_INSTANCES[@]}"; do
  EP="$(aws rds describe-db-instances --region "$DST_REGION" --db-instance-identifier "${id}-dr-test" --query 'DBInstances[0].Endpoint.Address' --output text)"
  echo "  ${id}-dr-test -> ${EP}:5432"
done

# --- 5. DynamoDB: export point-in-time (origem) + import cross-region (destino) ---
log "Preparando bucket de export S3 '${EXPORT_BUCKET}' em ${DST_REGION}..."
aws s3api head-bucket --bucket "$EXPORT_BUCKET" --region "$DST_REGION" 2>/dev/null || \
  aws s3api create-bucket --bucket "$EXPORT_BUCKET" --region "$DST_REGION" --create-bucket-configuration "LocationConstraint=${DST_REGION}" >/dev/null

TABLE_ARN="$(aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$SRC_REGION" --query 'Table.TableArn' --output text)"
KEY_SCHEMA="$(aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$SRC_REGION" --query 'Table.KeySchema' --output json)"
ATTR_DEFS="$(aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$SRC_REGION" --query 'Table.AttributeDefinitions' --output json)"

log "Exportando '${DYNAMO_TABLE}' (point-in-time) para o S3..."
S3_PREFIX="dr-test-${TS}"
EXPORT_ARN="$(aws dynamodb export-table-to-point-in-time --region "$SRC_REGION" \
  --table-arn "$TABLE_ARN" --s3-bucket "$EXPORT_BUCKET" --s3-prefix "$S3_PREFIX" \
  --export-format DYNAMODB_JSON --query 'ExportDescription.ExportArn' --output text)"

while true; do
  STATUS="$(aws dynamodb describe-export --export-arn "$EXPORT_ARN" --region "$SRC_REGION" --query 'ExportDescription.ExportStatus' --output text)"
  [ "$STATUS" = "IN_PROGRESS" ] || break
  sleep 10
done
[ "$STATUS" = "COMPLETED" ] || die "Export do DynamoDB terminou com status '${STATUS}' — não é seguro prosseguir com o import."

EXPORT_ID="$(basename "$EXPORT_ARN")"
# CUIDADO: S3KeyPrefix precisa apontar só para a subpasta .../data/ (nunca a
# pasta pai, que também tem manifest-summary.json/manifest-files.json/.md5) e
# --input-compression-type precisa ser GZIP — os arquivos de export do
# DynamoDB point-in-time SEMPRE vêm comprimidos. Sem os dois, o import falha
# com ItemValidationError (confirmado ao vivo nesta sessão: 1a tentativa sem
# esses dois ajustes deu 0/40 itens importados, ErrorCount 8).
DATA_PREFIX="${S3_PREFIX}/AWSDynamoDB/${EXPORT_ID}/data/"

log "Tabela '${DYNAMO_TABLE}' já existe em ${DST_REGION}? Removendo antes de reimportar (import-table sempre cria a tabela do zero)..."
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$DST_REGION" >/dev/null 2>&1; then
  aws dynamodb delete-table --table-name "$DYNAMO_TABLE" --region "$DST_REGION" >/dev/null
  aws dynamodb wait table-not-exists --table-name "$DYNAMO_TABLE" --region "$DST_REGION"
fi

log "Importando '${DYNAMO_TABLE}' em ${DST_REGION}..."
TABLE_PARAMS="$(python3 -c "
import json
print(json.dumps({
    'TableName': '${DYNAMO_TABLE}',
    'KeySchema': json.loads('''${KEY_SCHEMA}'''),
    'AttributeDefinitions': json.loads('''${ATTR_DEFS}'''),
    'BillingMode': 'PAY_PER_REQUEST',
}))
")"
IMPORT_ARN="$(aws dynamodb import-table --region "$DST_REGION" \
  --s3-bucket-source "S3Bucket=${EXPORT_BUCKET},S3KeyPrefix=${DATA_PREFIX}" \
  --input-format DYNAMODB_JSON --input-compression-type GZIP \
  --table-creation-parameters "$TABLE_PARAMS" \
  --query 'ImportTableDescription.ImportArn' --output text)"

while true; do
  STATUS="$(aws dynamodb describe-import --import-arn "$IMPORT_ARN" --region "$DST_REGION" --query 'ImportTableDescription.ImportStatus' --output text)"
  [ "$STATUS" = "IN_PROGRESS" ] || break
  sleep 10
done

if [ "$STATUS" != "COMPLETED" ]; then
  aws dynamodb describe-import --import-arn "$IMPORT_ARN" --region "$DST_REGION" --output json
  die "Import do DynamoDB terminou com status '${STATUS}' — ver detalhes acima e o CloudWatch Logs (/aws-dynamodb/imports)."
fi

ITEMS="$(aws dynamodb describe-import --import-arn "$IMPORT_ARN" --region "$DST_REGION" --query 'ImportTableDescription.ImportedItemCount' --output text)"
log "DynamoDB importado: ${ITEMS} itens em ${DYNAMO_TABLE} (${DST_REGION})."

cat <<MSG

Restore de dados completo em ${DST_REGION}. Pra apontar os pods do cluster
de DR pros novos endpoints (mesma senha do master, preservada pelo
snapshot):

  kubectl create secret generic donation-service-secret -n fiap-tc-f5 \\
    --from-literal=DATABASE_URL="postgresql://postgres:<SENHA>@<endpoint-donation>:5432/donation_db" \\
    --from-literal=AWS_SQS_URL="<mesma URL de produção>" \\
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret generic ngo-service-secret -n fiap-tc-f5 \\
    --from-literal=DATABASE_URL="postgresql://postgres:<SENHA>@<endpoint-ngo>:5432/ngo_db" \\
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl patch configmap volunteer-service-config-map -n fiap-tc-f5 \\
    --type merge -p '{"data":{"AWS_REGION":"${DST_REGION}"}}'

  kubectl rollout restart deployment/donation-service deployment/ngo-service deployment/volunteer-service -n fiap-tc-f5

Nota (achado real, sessão anterior): o node group do cluster de DR (1 node
t3.small, mínimo de propósito) pode não ter capacidade de pod suficiente
pros novos pods do rollout restart (erro "Too many pods"). Se acontecer:
  eksctl scale nodegroup --cluster ${DR_CLUSTER} --region ${DST_REGION} --name dr-test-ng --nodes 2 --nodes-min 1 --nodes-max 2

Quando terminar, destrua com:
  ./dr-test-destroy-data.sh ${DST_REGION} ${SRC_REGION}
MSG
