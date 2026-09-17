# Runbook — Restore de DynamoDB (`SolidaryTechVolunteers`)

**Quando usar:** dado corrompido ou perdido na tabela de voluntários — `volunteer-service` (Tier 1).

**Antes de começar**
- Confirme sessão AWS Academy ativa: `../../../scripts/00-check-session.sh` (ou `aws sts get-caller-identity` direto).
- Registre T0 (início do incidente/restore).
- ⚠️ **DynamoDB não tem "rename".** Diferente do RDS, não dá pra trocar o nome da tabela restaurada de volta pro nome original sem apagar a tabela antiga primeiro. O padrão deste runbook é **repontar a aplicação para o nome da tabela nova**, não recriar `SolidaryTechVolunteers` no lugar da antiga — mais seguro, menos passos destrutivos.

Existem dois caminhos. Use o **1** por padrão.

---

## Caminho 1 — Point-in-Time Restore (PITR nativo)

RPO ~1 min, até 35 dias de janela. Cria uma **tabela nova**.

```bash
SOURCE_TABLE="SolidaryTechVolunteers"
NEW_TABLE="${SOURCE_TABLE}-restore-$(date +%Y%m%d%H%M)"
RESTORE_TIME="2026-08-23T10:00:00Z"   # UTC, imediatamente ANTES do incidente

# Restaura para um instante específico
aws dynamodb restore-table-to-point-in-time \
  --source-table-name "$SOURCE_TABLE" \
  --target-table-name "$NEW_TABLE" \
  --restore-date-time "$RESTORE_TIME"

# Ou, para o último estado consistente possível:
# aws dynamodb restore-table-to-point-in-time \
#   --source-table-name "$SOURCE_TABLE" \
#   --target-table-name "$NEW_TABLE" \
#   --use-latest-restorable-time

aws dynamodb wait table-exists --table-name "$NEW_TABLE"
```

## Caminho 2 — via AWS Backup vault

Para pontos fora da janela de 35 dias do PITR nativo.

```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name fiap-tc-f5-backup-vault \
  --query "RecoveryPoints[?contains(ResourceArn, 'SolidaryTechVolunteers')]"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws backup start-restore-job \
  --recovery-point-arn "<RecoveryPointArn do passo anterior>" \
  --iam-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/LabRole" \
  --metadata "{\"targetTableName\":\"SolidaryTechVolunteers-restore-fromvault\"}"

aws backup describe-restore-job --restore-job-id "<id retornado acima>"
```

---

## ⚠️ A tabela restaurada nasce "pelada"

O restore (por qualquer um dos dois caminhos) **não copia**: PITR, tags, auto-scaling, TTL, streams. Reaplique manualmente na tabela nova antes de usá-la em produção:

```bash
# Reabilita PITR contínuo na tabela restaurada
aws dynamodb update-continuous-backups \
  --table-name "$NEW_TABLE" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# Retagueia para voltar a entrar no plano do AWS Backup (module.backup seleciona por essa tag)
TABLE_ARN=$(aws dynamodb describe-table --table-name "$NEW_TABLE" \
  --query "Table.TableArn" --output text)
aws dynamodb tag-resource --resource-arn "$TABLE_ARN" \
  --tags Key=Backup,Value=true Key=Name,Value="fiap-tc-f5-${NEW_TABLE}"
```

## Validação antes do cutover

```bash
aws dynamodb scan --table-name "$NEW_TABLE" --max-items 5

# Conta total de itens (compare com a expectativa do time)
aws dynamodb scan --table-name "$NEW_TABLE" --select COUNT
```

## Cutover

1. Atualize `AWS_DYNAMODB_TABLE` na configuração do `volunteer-service` (Secret/ConfigMap do Deployment) para `$NEW_TABLE`.
2. Reaplique/sincronize (via ArgoCD ou `kubectl rollout restart deployment/volunteer-service`).
3. Rode o smoke test abaixo.
4. Depois de validado, avalie se vale importar o Terraform (`terraform import`) da tabela nova para dentro do `module.dynamodb`, atualizando `aws_dynamodb_table_name` no `tfvars` — assim o estado do Terraform não fica dessincronizado da realidade.
5. Só apague a tabela antiga corrompida depois de ter certeza de que não precisa mais dela para investigação — `aws dynamodb delete-table --table-name SolidaryTechVolunteers` (irreversível).

## Smoke test pós-restore

```bash
curl -s http://localhost:8083/health

curl -s -X POST http://localhost:8083/volunteers \
  -H "Content-Type: application/json" \
  -d '{"name":"Smoke Test DRP","email":"drp@teste.com","ngo_id":1}'

curl -s http://localhost:8083/volunteers/1
```

Registre o resultado (RTO real, o que travou) em [`../drills/TEMPLATE.md`](../drills/TEMPLATE.md).
