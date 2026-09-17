# Runbook — Restore de Kubernetes (Velero) e rebuild do EKS

**Quando usar:** perda de um namespace/Deployment/PVC específico (Caso A) ou perda do cluster EKS inteiro (Caso B).

**Antes de começar**
- Confirme sessão AWS Academy ativa: `../../../scripts/00-check-session.sh` (ou `aws sts get-caller-identity` direto) — o Caso B pode facilmente passar de 1h, reautentique se necessário no meio do processo.
- Registre T0.
- CLI necessária: `aws`, `kubectl`, [`velero`](https://velero.io/docs/main/basic-install/#install-the-cli) (mesma versão major do chart, `velero_chart_version` no `tfvars`), `terraform` (só pro Caso B — já é dependência dos scripts abaixo).
- Configure o `kubeconfig` do cluster atual (Caso A — cluster já de pé):
  ```bash
  aws eks update-kubeconfig --name <nome-do-cluster> --region us-east-1
  # ou, via script (lê o nome do cluster direto do terraform output, sem digitar nada):
  ../../../scripts/07-update-kubeconfig.sh
  ```
- **Scripts de automação**: os comandos de infraestrutura do Caso B abaixo usam [`scripts/`](../../../scripts) (raiz do repo `fiap-tech-challenge-fase-5-infra` — ver [`scripts/README.md`](../../../scripts/README.md)) em vez de `terraform` digitado na mão, reduzindo erro de flag/comando esquecido durante um incidente sob pressão. Rode a partir da raiz do repo.

---

## Caso A — perdeu um namespace/Deployment/PVC, cluster continua de pé

```bash
# 1. Liste os backups disponíveis (agendados diariamente pelo module.velero)
velero backup get

# 2. Antes de restaurar, PAUSE o auto-sync do ArgoCD para a Application afetada
#    — evita o ArgoCD brigar com o Velero por causa dos mesmos recursos no meio do restore
kubectl -n argocd patch application <nome-da-app> --type merge \
  -p '{"spec":{"syncPolicy":null}}'

# 3. Restaure só o namespace afetado
velero restore create restore-$(date +%Y%m%d%H%M) \
  --from-backup <nome-do-backup-do-passo-1> \
  --include-namespaces <namespace-afetado>

# 4. Acompanhe
velero restore describe restore-<timestamp> --details
velero restore logs restore-<timestamp>

# 5. Confirme que os recursos voltaram
kubectl get pods,pvc,deploy -n <namespace-afetado>

# 6. Reative o auto-sync do ArgoCD
kubectl -n argocd patch application <nome-da-app> --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

## Caso B — cluster EKS inteiro perdido/corrompido

A ordem importa: **infra primeiro (Terraform), GitOps depois (ArgoCD), dados de runtime por último (Velero)**.

```bash
# 1. Reconstrua a infraestrutura a partir do zero, via scripts/ (raiz do repo infra)
cd fiap-tech-challenge-fase-5-infra
./scripts/00-check-session.sh
./scripts/01-bootstrap-backend.sh   # idempotente — não recria o bucket S3 do state se ele sobreviveu
./scripts/02-init.sh <dev|prd>
./scripts/05-plan.sh <dev|prd>      # revise o plano antes de confirmar o próximo passo
./scripts/06-apply.sh <dev|prd>     # pede confirmação interativa antes de aplicar

# 2. Confirme que o cluster está pronto (lê o nome do cluster do terraform output)
./scripts/07-update-kubeconfig.sh   # roda "aws eks update-kubeconfig" + "kubectl get nodes"
```

> Atalho: `./scripts/run-all.sh <dev|prd>` encadeia os passos 1 e 2 acima numa chamada só (inclui `fmt`/`validate`/`test` no meio do caminho como validação extra — não tocam a AWS, sem custo). Equivalente aos comandos manuais `terraform init`/`apply` + `aws eks update-kubeconfig` que este runbook usava antes de `scripts/` existir.

Isso recria (se necessário — recursos que sobreviveram não são tocados, o Terraform só reconcilia o que mudou): VPC, EKS, node group, `module.argocd`, `module.backup`, `module.velero`. **RDS e DynamoDB só são recriados se também tiverem sido perdidos** — se sobreviveram, seguem intactos e a aplicação nem precisa de restore de dados, só do cluster.

```bash
# 3. Confirme ArgoCD de pé
kubectl -n argocd get pods
```

O ArgoCD, assim que sobe, começa a reconciliar a partir do Git — isso já recria namespaces, Deployments, Services, ConfigMaps definidos como código. **Espere o sync terminar antes do próximo passo**, senão o restore do Velero (passo 4) compete com o ArgoCD criando os mesmos recursos.

```bash
# 4. Restaure o que NÃO está no Git (dados de PVC, secrets gerados em runtime)
velero backup get
velero restore create restore-full-$(date +%Y%m%d%H%M) \
  --from-backup <backup-mais-recente-do-passo-anterior>

velero restore describe restore-full-<timestamp> --details
```

```bash
# 5. Verifique todos os pods de pé
kubectl get pods -A | grep -v Running
```

## Validação

```bash
kubectl get pods,pvc -A
velero backup describe <backup-mais-recente>   # confirma que o backup usado era íntegro
```

## Smoke test pós-restore (os três serviços)

```bash
curl -s http://localhost:8081/health   # ngo-service
curl -s http://localhost:8082/health   # donation-service
curl -s http://localhost:8083/health   # volunteer-service

curl -s http://localhost:8081/ngos
curl -s http://localhost:8082/donations
curl -s http://localhost:8083/volunteers/1
```

## Observações

- Se **só o EKS morreu** e RDS/DynamoDB sobreviveram, o Caso B ainda se aplica para a parte de cluster — mas pule qualquer restore de dados, já que os bancos não foram afetados.
- O restore do Velero recria PVCs a partir de snapshot EBS — leva alguns minutos por volume, dependendo do tamanho.
- Se o `velero restore describe` mostrar itens com status `PartiallyFailed`, rode `velero restore logs <nome>` para ver o motivo antes de declarar o incidente resolvido.
- Os passos 1–2 do Caso B (`scripts/00` a `scripts/07`) reduzem a variância de execução manual do RTO estimado (ver [`DRP.md`](../DRP.md), seção 4) — não o tempo de provisionamento do lado da AWS (control plane do EKS, node group, releases Helm), que continua sendo o maior componente do tempo total.

Registre o resultado (RTO real, o que travou) em [`../drills/TEMPLATE.md`](../drills/TEMPLATE.md).
