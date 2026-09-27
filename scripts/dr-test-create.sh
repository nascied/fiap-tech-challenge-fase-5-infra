#!/usr/bin/env bash
# Cria um cluster EKS MÍNIMO numa região diferente (padrão us-west-2) via
# eksctl — de propósito, NÃO via Terraform/módulo raiz. Motivo (ver
# CLAUDE.md/docs/drp/DRP.md pro detalhe completo): o provider "aws" da raiz
# não tem `region` explícita (só segue a env var/perfil ativo), os scripts
# 00-08 só aceitam dev|prd, e o main.tf é monolítico (sobe o stack inteiro,
# sem um caminho pra "só EKS mínimo"). eksctl resolve isso sem precisar
# tocar em nada do Terraform/state principal.
#
# Instala o Velero no cluster novo apontando pro MESMO bucket S3 de produção
# (accessMode: ReadOnly — nunca escreve, só lê) pra validar, de verdade, que
# o backup sobrevive à perda de uma região inteira. Opcional e isolado: não
# interfere em nada do ambiente dev/prd (eksctl cria sua própria VPC).
#
# Uso: ./dr-test-create.sh [regiao] [nome-cluster]
#   regiao       (opcional, default: us-west-2 — precisa ser diferente de
#                us-east-1 pra fazer sentido como teste de DR)
#   nome-cluster (opcional, default: fiap-tc-f5-dr-test)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_aws_cli
check_aws_session
command -v eksctl >/dev/null 2>&1 || die "eksctl não encontrado no PATH."
command -v helm >/dev/null 2>&1 || die "helm não encontrado no PATH."

DR_REGION="${1:-us-west-2}"
DR_CLUSTER="${2:-fiap-tc-f5-dr-test}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
VELERO_BUCKET="fiap-tc-f5-velero-backups-${ACCOUNT_ID}"
LAB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"

warn "Isso cria um cluster EKS real (1 node t3.small) em '${DR_REGION}' — custo real (~US\$0,10-0,15/h), leva ~15-20min pra subir."
read -r -p "Confirma a criação? [y/N] " CONFIRM
case "$CONFIRM" in
  y|Y) ;;
  *) die "Cancelado pelo usuário." ;;
esac

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# iam.serviceRoleARN/iam.instanceRoleARN apontando pra LabRole já existente é
# ESSENCIAL — sem isso, eksctl cria IAM roles novas via CloudFormation por
# padrão, proibido nesta conta AWS Academy (mesma restrição documentada em
# todo o resto do projeto).
cat > "${WORKDIR}/cluster.yaml" <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${DR_CLUSTER}
  region: ${DR_REGION}
  version: "1.35"
iam:
  serviceRoleARN: ${LAB_ROLE_ARN}
managedNodeGroups:
  - name: dr-test-ng
    instanceType: t3.small
    desiredCapacity: 1
    minSize: 1
    maxSize: 1
    iam:
      instanceRoleARN: ${LAB_ROLE_ARN}
EOF

log "Criando cluster EKS mínimo '${DR_CLUSTER}' em '${DR_REGION}' (reaproveitando LabRole, sem criar role nova)..."
eksctl create cluster -f "${WORKDIR}/cluster.yaml"

log "Instalando Velero, apontando pro bucket de produção '${VELERO_BUCKET}' (us-east-1, accessMode ReadOnly — nunca escreve nele)..."
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update vmware-tanzu >/dev/null

cat > "${WORKDIR}/velero-values.yaml" <<EOF
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.11.0
    volumeMounts:
      - mountPath: /target
        name: plugins
credentials:
  useSecret: false
configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: ${VELERO_BUCKET}
      accessMode: ReadOnly
      config:
        region: us-east-1
  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: us-east-1
upgradeCRDs: false
snapshotsEnabled: true
deployNodeAgent: true
EOF

helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  --version 8.1.0 \
  -f "${WORKDIR}/velero-values.yaml" \
  --wait --timeout 5m

log "Cluster de DR pronto. Backups reais descobertos no bucket de produção:"
kubectl get backups -n velero

cat <<MSG

Pra restaurar um namespace de teste (ex.: fiap-tc-f5) a partir de um dos
backups acima:

  kubectl apply -f - <<'EOF'
  apiVersion: velero.io/v1
  kind: Restore
  metadata:
    name: dr-test-restore
    namespace: velero
  spec:
    backupName: <nome-do-backup-listado-acima>
    includedNamespaces: [fiap-tc-f5]
  EOF

Nota: este script sozinho só cobre o estado do cluster Kubernetes (Velero) —
serviços que dependem de RDS/DynamoDB reais (ex. donation-service/ngo-service)
não ficam saudáveis aqui até a camada de dados também ser restaurada
(sem VPC peering pro RDS de produção, então precisa de um restore próprio
nesta região). Rode ./dr-test-restore-data.sh logo em seguida pra resolver
isso — fluxo validado de ponta a ponta contra a AWS Academy real (RDS via
snapshot+cópia cross-region+restore, DynamoDB via export+import cross-region).

Quando terminar, destrua com:
  ./dr-test-destroy.sh ${DR_REGION} ${DR_CLUSTER}
MSG
