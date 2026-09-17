# Runbook — Restore de RDS (`donation_db` / `ngo_db`)

**Quando usar:** dado corrompido ou perdido em `donation-service` (Tier 0) ou `ngo-service` (Tier 1) — erro de aplicação, `DELETE`/`UPDATE` indevido, migração quebrada, etc.

**Antes de começar**
- Confirme que a sessão AWS Academy está ativa: `../../../scripts/00-check-session.sh` (ou `aws sts get-caller-identity` direto) — sessões expiram em ~4h e o restore de RDS pode levar 20–30 min.
- Registre o horário de início (T0) para calcular o RTO real depois.
- **Não apague nada do ambiente com problema** até o restore estar validado — o objetivo é ter os dois lados (quebrado e restaurado) disponíveis para comparar.

Existem dois caminhos. Use o **1** por padrão — é mais rápido e mais granular.

---

## Caminho 1 — Point-in-Time Restore (PITR nativo)

RPO ~5 min, restaura para qualquer segundo dentro da janela de retenção (7 dias). Cria uma **instância nova** — o RDS não restaura em cima da instância original.

```bash
DB_ID="donation-service"   # ou "ngo-service"
RESTORE_TIME="2026-08-23T10:00:00Z"   # UTC, o momento imediatamente ANTES do incidente
NEW_ID="${DB_ID}-restore-$(date +%Y%m%d%H%M)"

# 1. Confira a janela restaurável
aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].[EarliestRestorableTime,LatestRestorableTime]"

# 2. Copie a rede da instância original (subnet group e security group)
SUBNET_GROUP=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].DBSubnetGroup.DBSubnetGroupName" --output text)
SG_ID=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" --output text)

# 3. Restaure
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier "$DB_ID" \
  --target-db-instance-identifier "$NEW_ID" \
  --restore-time "$RESTORE_TIME" \
  --db-subnet-group-name "$SUBNET_GROUP" \
  --vpc-security-group-ids "$SG_ID" \
  --db-instance-class db.t3.micro \
  --no-multi-az

# 4. Aguarde ficar disponível (leva alguns minutos)
aws rds wait db-instance-available --db-instance-identifier "$NEW_ID"
```

Para "restaurar para agora mesmo" (último estado consistente, útil se o problema não é temporal e sim um recurso que sumiu), troque `--restore-time` por `--use-latest-restorable-time`.

## Caminho 2 — via AWS Backup vault

Use quando precisar de um ponto **mais antigo que 7 dias não existe** (retenção do PITR nativo) — não é o caso hoje (retenção igual em ambos), mas fica documentado caso a retenção do plano mude no futuro.

```bash
# 1. Liste os recovery points disponíveis
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name fiap-tc-f5-backup-vault \
  --query "RecoveryPoints[?contains(ResourceArn, 'donation-service')]"

# 2. Inicie o restore (LabRole é a mesma role usada pelo module.backup)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws backup start-restore-job \
  --recovery-point-arn "<RecoveryPointArn do passo 1>" \
  --iam-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/LabRole" \
  --metadata "{\"DBInstanceIdentifier\":\"donation-service-restore-fromvault\"}"

# 3. Acompanhe
aws backup describe-restore-job --restore-job-id "<id retornado no passo 2>"
```

---

## Validação antes do cutover

```bash
NEW_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$NEW_ID" \
  --query "DBInstances[0].Endpoint.Address" --output text)

# Senha compartilhada entre donation_db/ngo_db (random_password.this, main.tf raiz) —
# nunca em texto plano. Pegue do Secrets Manager (fiap-tc-f5-donation-service,
# chave DATABASE_URL) ou do output sensível do Terraform:
#   terraform output -json aws_db_instance_connection_strings
DB_PASSWORD="<senha do Secrets Manager ou do output sensível do Terraform>"

psql "postgres://postgres:${DB_PASSWORD}@${NEW_ENDPOINT}:5432/donation_db?sslmode=require" \
  -c "SELECT count(*), max(created_at) FROM donations;"
```

Confirme que os dados batem com o esperado (contagem de linhas plausível, timestamp mais recente é anterior ao incidente).

## Cutover

1. Atualize `DATABASE_URL` na configuração da aplicação (Secret/ConfigMap consumido pelo Deployment do `donation-service`/`ngo-service` no cluster) para apontar para `$NEW_ENDPOINT`.
2. Reaplique/sincronize (via ArgoCD ou `kubectl rollout restart deployment/<serviço>`).
3. Rode o smoke test (seção abaixo).
4. Só depois de validado, decida o destino da instância antiga:
   ```bash
   # Renomeia a quebrada para investigação posterior, sem apagar ainda
   aws rds modify-db-instance --db-instance-identifier "$DB_ID" \
     --new-db-instance-identifier "${DB_ID}-incident-$(date +%Y%m%d)" \
     --apply-immediately

   # Opcional: depois de confirmar estabilidade por alguns dias, renomeie a
   # restaurada de volta ao identifier original (evita reconfigurar DATABASE_URL de novo)
   aws rds modify-db-instance --db-instance-identifier "$NEW_ID" \
     --new-db-instance-identifier "$DB_ID" \
     --apply-immediately
   ```

## Smoke test pós-restore

```bash
curl -s http://localhost:8082/health        # donation-service
curl -s http://localhost:8082/donations      # confere leitura
curl -s -X POST http://localhost:8082/donations \
  -H "Content-Type: application/json" \
  -d '{"ngo_id":1,"amount":10,"donor_name":"Smoke Test DRP"}'   # confere escrita
```
(Troque porta/rota para `ngo-service`: `8081`, `/health`, `/ngos` conforme o serviço restaurado.)

Registre o resultado (RTO real, o que travou) em [`../drills/TEMPLATE.md`](../drills/TEMPLATE.md).
