# scripts/

Automação do fluxo de Terraform deste repositório, passo a passo. Cada script
faz uma coisa só e pode ser chamado isoladamente; `run-all.sh` encadeia todos
na ordem certa. Também dá pra usar via `make` (ver `Makefile` na raiz do repo).

## Pré-requisitos

- `terraform` >= 1.10.0, `aws` CLI v2 (precisa de `aws configure export-credentials`), `kubectl` (só para `07-update-kubeconfig.sh`).
- Sessão de credenciais temporárias da AWS Academy Learner Lab já exportada neste shell (variáveis `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN` ou `~/.aws/credentials`) — expira em ~4h, precisa reexportar entre sessões de trabalho.

## Scripts

| Ordem | Script | O que faz | Precisa de credencial AWS real? |
|---|---|---|---|
| 0 | `00-check-session.sh` | Confere se a sessão Academy está válida (`aws sts get-caller-identity`) | Sim |
| 1 | `01-bootstrap-backend.sh` | Cria/atualiza o bucket S3 do state remoto (`iac/terraform/bootstrap-backend`) | Sim |
| 2 | `02-init.sh <dev\|prd>` | `terraform init` do módulo raiz contra o backend do ambiente | Sim (só pra acessar o bucket) |
| 3 | `03-fmt-validate.sh` | `terraform fmt -check` + `validate` + `tflint` (se instalado) | Não |
| 4 | `04-test.sh` | `terraform test` (`iac.tftest.hcl`, usa `mock_provider`) | Não |
| 5 | `05-plan.sh <dev\|prd>` | Detecta se o namespace `fiap-tc-f5` já existe (`kubectl get namespace`, exporta `TF_VAR_k8s_namespace_exists`) e roda `terraform plan`, salvando em `iac/terraform/tfplan` | Sim |
| 6 | `06-apply.sh <dev\|prd>` | Aplica o `tfplan` salvo, com confirmação interativa | Sim |
| 7 | `07-update-kubeconfig.sh` | `aws eks update-kubeconfig` + `kubectl get nodes`, usando o nome do cluster do `terraform output` | Sim |
| 8 | `08-destroy.sh <dev\|prd>` | `terraform destroy`, com dupla confirmação (nome do ambiente + revisão do plano) | Sim |
| — | `run-all.sh <dev\|prd>` | Roda 0→7 em sequência | Sim |

`lib/common.sh` concentra as funções compartilhadas (log/warn/die, validação de ambiente, checagem de sessão) — não é executado direto.

## Scripts opcionais — teste de DR cross-region (`dr-test-*.sh`)

Fora do ciclo `dev|prd` acima **de propósito** — não usam `require_env`, não tocam no state/main.tf principal, e não fazem parte do `run-all.sh`. Servem só pra validar, sob demanda, que o backup do Velero sobrevive à perda de uma região inteira, criando um cluster EKS **mínimo e descartável** numa região diferente (padrão `us-west-2`) via `eksctl` e restaurando a partir do bucket S3 **real de produção** (`us-east-1`, montado `accessMode: ReadOnly` — nunca escreve nele).

| Script | O que faz | Precisa de credencial AWS real? |
|---|---|---|
| `dr-test-create.sh [regiao] [nome-cluster]` | Cria o cluster (`eksctl`, reaproveitando `LabRole` — sem IAM role nova) e instala o Velero apontado pro bucket de produção, com confirmação interativa | Sim |
| `dr-test-restore-data.sh [regiao-destino] [regiao-origem] [nome-cluster]` | Restaura a camada de dados (RDS via snapshot+cópia cross-region+restore, DynamoDB via export+import cross-region) na região do cluster de teste — ver seção própria abaixo | Sim |
| `dr-test-destroy-data.sh [regiao-destino] [regiao-origem]` | Destrói tudo que `dr-test-restore-data.sh` criou (RDS/DynamoDB/bucket de export/SG/subnet group/snapshots) — nunca toca a produção | Sim |
| `dr-test-destroy.sh [regiao] [nome-cluster]` | Destrói o cluster de teste (`eksctl delete cluster`), com dupla confirmação (nome do cluster) | Sim |

**Por que isso não usa o `main.tf`/scripts `00`-`08` já existentes** (achado real, validado nesta sessão contra a conta AWS Academy):
1. `require_env` (`lib/common.sh`) só aceita `dev|prd` — não existe um terceiro ambiente "dr-test" no `.tfvars`.
2. `07-update-kubeconfig.sh` tem `--region us-east-1` fixo — não dá pra apontar pra outra região sem editar o script.
3. `provider "aws"` (`iac/terraform/provider.tf`) **não tem `region` explícita** — segue só a env var/perfil ativo da sessão AWS CLI, completamente desacoplado de `var.aws_region` (que só chega a alguns módulos como string simples, ex. `velero`/`secretsmanager`/`cluster-autoscaler`). Rodar o `main.tf` inteiro com a sessão apontada pra `us-west-2` tentaria recriar TODO o stack lá (VPC/EKS/RDS/DynamoDB/SQS/ECR/ArgoCD/Backup/Velero/Lambda), não só um EKS mínimo.
4. `main.tf` da raiz é monolítico — não existe um caminho "só sobe o EKS" sem subir o resto.
5. Nomes de bucket S3 (`velero_bucket_name`) não são parametrizados por região — reaproveitar o mesmo bucket de origem (não recriar um novo) é o comportamento desejado aqui, então isso nem seria um problema a resolver, só reforça que o caminho certo é apontar pro bucket existente, não replicar infraestrutura.

`eksctl` contorna os 5 pontos acima numa tacada só: cluster isolado, região arbitrária via parâmetro, sem tocar em nenhum state/módulo Terraform existente, reaproveitando `LabRole` (`iam.serviceRoleARN`/`iam.instanceRoleARN` no YAML gerado) pra não esbarrar na restrição de "sem IAM role própria" da conta Academy.

**Validado de ponta a ponta contra a AWS Academy real** (não é só teoria): cluster `fiap-tc-f5-dr-test` criado em `us-west-2` (~14min), Velero instalado apontando pro bucket real `fiap-tc-f5-velero-backups-<account-id>` (`us-east-1`), os 2 backups de produção descobertos automaticamente (`backup-sync` controller) e um restore real do namespace `fiap-tc-f5` completado com sucesso (38/38 itens). Ver `CLAUDE.md`, seção "Teste real de DR cross-region", pro relato completo (incluindo as 2 limitações esperadas encontradas: sem VPC peering pro RDS de produção, e capacidade de pod limitada pelo único node pequeno — nenhuma delas é bug deste script).

**Custo real**: ~US\$0,10–0,15/h enquanto o cluster de teste estiver de pé (1× `t3.small` + control plane EKS) — sempre rodar `dr-test-destroy.sh` ao terminar a validação.

### `dr-test-restore-data.sh`/`dr-test-destroy-data.sh` — fechando a lacuna da camada de dados

`dr-test-create.sh` sozinho só cobre o estado do cluster Kubernetes (Velero) — `donation-service`/`ngo-service` ficam `CrashLoopBackOff` porque não há RDS na região do cluster de teste, e não dá pra usar o RDS de produção sem VPC peering (que este teste não configura de propósito, pra não arriscar nada em produção). `dr-test-restore-data.sh` fecha essa lacuna, encapsulando o fluxo **validado ao vivo contra a AWS Academy real**:

- **RDS** (`donation-service`/`ngo-service`): não existe atalho — PITR nativo do RDS é *same-region*, então o caminho é sempre `create-db-snapshot` (origem) → `copy-db-snapshot --source-region` (cross-region) → `restore-db-instance-from-db-snapshot` (destino). O script cria/reaproveita um security group (porta 5432 liberada só pro CIDR da VPC) e um DB subnet group nas subnets privadas do cluster de teste — sem VPC peering nenhum, o RDS só precisa nascer **dentro** da mesma VPC dos pods. Senha do master é preservada automaticamente pelo snapshot.
- **DynamoDB** (`volunteer-service`): mesma lógica — `restore-table-to-point-in-time` também é *same-region* (cross-region de verdade exigiria Global Tables, não configurado neste projeto). Caminho usado: `export-table-to-point-in-time` (S3, região de origem) → `import-table` (região de destino).

🐛 **Bug real da API do DynamoDB, encontrado e corrigido nesta sessão** (o script já nasce com o fix): a primeira tentativa manual de `import-table` falhou com `ItemValidationError` (0 itens importados) porque (1) o `S3KeyPrefix` apontava pra uma pasta que misturava arquivos de dados (`data/*.json.gz`) com manifests do export (`manifest-summary.json`, `manifest-files.json`, `.md5`) — o `import-table` tenta ler **todo objeto sob o prefixo** como item, sem saber ignorar manifests —, e (2) faltou `--input-compression-type GZIP` (os exports point-in-time do DynamoDB sempre vêm comprimidos). O script aponta o prefixo só pra subpasta `.../data/` e sempre passa `GZIP` — evita repetir o erro.

**Validado de ponta a ponta com dados reais** (não só os bancos isolados — os 3 microsserviços rodando no cluster de teste, secrets/configmap atualizados e serviços reiniciados): `donation-service` (`GET /donations`), `ngo-service` (`GET /ngos`) e `volunteer-service` (`GET /volunteers/1`) voltaram a servir dados idênticos aos de produção. Achado colateral: o `rollout restart` pode esbarrar na capacidade de pod do node único do teste (`Too many pods`) — resolvido escalando o node group pra 2 nodes (`eksctl scale nodegroup ... --nodes 2`, comando impresso no fim do script).

**`dr-test-destroy-data.sh`** desfaz tudo (RDS/DynamoDB/bucket/SG/subnet group/snapshots em ambas as regiões) — pede a confirmação literal `destruir-dados-dr` (ação irreversível) e nunca toca a produção (RDS/DynamoDB reais ficam intocados; só os recursos com sufixo `-dr-test`/prefixo `-dr-<timestamp>` são removidos).

**Custo real adicional**: 2× RDS `db.t3.micro` (~US\$0,016/h cada) + tabela DynamoDB (`PAY_PER_REQUEST`, praticamente grátis em volume de teste) + bucket S3 pequeno — soma pouco, mas ainda é custo real enquanto ficar de pé.

## 🐛 `module.k8s_secrets` — `Invalid count argument` num cluster novo (bug real, confirmado, e como foi resolvido)

Rodar `terraform plan`/`apply` contra um ambiente **totalmente novo** (depois de um `destroy` completo, ou na primeira vez) batia neste erro:

```
Error: Invalid count argument
  on modules/k8s-secrets/main.tf line 34, in resource "kubernetes_namespace" "this":
  34:   count = contains(data.kubernetes_all_namespaces.this.namespaces, var.namespace) ? 0 : 1
The "count" value depends on resource attributes that cannot be determined
until apply, so Terraform cannot predict how many instances will be
created. To work around this, use the -target argument to first apply only
the resources that the count depends on.
```

Causa: os providers `kubernetes`/`helm` (`provider.tf`, raiz) são configurados a partir de 3 outputs de `module.eks` (`aws_eks_cluster_endpoint`/`_certificate_authority_data`/`_name`). Enquanto o cluster EKS não existe de verdade, esses outputs ficam "unknown até o apply" — e sem a config do provider resolvida, o antigo `data.kubernetes_all_namespaces` (e o `count` de `kubernetes_namespace.this` que dependia dele) não avaliava em `terraform plan`. Esse risco já estava documentado como "não confirmado" antes desta sessão (só reproduzido dentro do `terraform test` com `mock_provider`) — confirmado de verdade rodando uma infra do zero.

**Fix definitivo, na raiz do problema**: `kubernetes_namespace.this` trocou de `count = contains(data.kubernetes_all_namespaces.this.namespaces, var.namespace) ? 0 : 1` pra `count = var.namespace_exists ? 0 : 1` — um **bool simples**, sempre conhecido em `plan`, independente de o cluster existir ou não. `data.tf` do módulo foi removido (não sobrou nenhum `data` no módulo). Isso elimina o erro por completo, sem precisar de nenhum apply em duas fases (a alternativa anterior, um script `04b-apply-eks-first.sh` com `terraform apply -target=module.eks`, foi removida — não é mais necessária).

**Trade-off assumido conscientemente**: um bool simples não se "autodescobre" contra o cluster real como o data source fazia — precisa que alguém (ou algo) o mantenha correto a cada apply, senão o risco vira o oposto (tentar recriar um namespace que já existe → `already exists`). Resolvido **automaticamente**, não manualmente: `05-plan.sh` detecta o estado real do cluster com `kubectl get namespace fiap-tc-f5` (via o `terraform output aws_eks_cluster_name` + `aws eks update-kubeconfig`, ambos silenciosos/best-effort) e exporta `TF_VAR_k8s_namespace_exists` antes do `terraform plan` — ninguém precisa lembrar de virar a flag manualmente. Fallback seguro se a detecção falhar por qualquer motivo (cluster ainda não existe, `kubectl` indisponível, etc.): assume `false` — pior caso, um erro real e óbvio (`already exists`), não mais um `Invalid count argument` enigmático. Mesma detecção replicada como step no `.github/workflows/terraform.yml` (antes do "Terraform Plan"), já que esse pipeline roda direto, sem passar pelos scripts locais.

Alternativa **rejeitada** de propósito: `null_resource`+`kubectl apply` no `modules/k8s-secrets` — decisão explícita do usuário de manter `kubernetes_namespace` como recurso nativo do provider `kubernetes` (ver `CLAUDE.md`, seção `module.k8s_secrets`).

## Credenciais AWS Academy → `TF_VAR_*`

`var.github_token`/`var.pagerduty_webhook_secret` (module.incident_bridge) — únicas variáveis sensíveis sem default hoje — **não são cobertas por nenhum script**, precisam ser exportadas manualmente antes de `05-plan.sh`/`06-apply.sh` ao rodar localmente (a pipeline `.github/workflows/terraform.yml` já resolve as duas via os secrets `INCIDENT_BRIDGE_GITHUB_TOKEN`/`PAGERDUTY_WEBHOOK_SECRET` do repositório):

```bash
export TF_VAR_github_token="ghp_..."             # PAT com permissão de repository_dispatch neste repo
export TF_VAR_pagerduty_webhook_secret="..."     # gerado pelo PagerDuty ao criar a webhook subscription V3
```

Sem isso, `terraform plan`/`apply`/`destroy` falha com "No value for required variable" — ver `iac/terraform/modules/lambda/README.md`.

## Exemplos

```bash
# Primeira vez num ambiente novo, do zero até o cluster acessível
./scripts/run-all.sh dev

# Só validar sem tocar a AWS (útil com sessão Academy expirada)
./scripts/03-fmt-validate.sh
./scripts/04-test.sh

# Aplicar uma mudança pontual em prd
./scripts/02-init.sh prd
./scripts/05-plan.sh prd
./scripts/06-apply.sh prd

# Teste opcional de DR cross-region (fora do ciclo dev/prd acima)
./scripts/dr-test-create.sh          # us-west-2 / fiap-tc-f5-dr-test (defaults)
./scripts/dr-test-destroy.sh         # destrói ao terminar a validação
```

## O que os scripts NÃO fazem

- Não guardam nem comitam credencial nenhuma.
- Não rodam `apply`/`destroy` sem confirmação interativa.
- Não substituem o `.github/workflows/terraform.yml` — esse arquivo ainda é resíduo do projeto anterior (ToggleMaster/Fase 3, nomes de serviço errados, Redis, repo de destino errado) e precisa de ajuste separado antes de virar o pipeline de CI real.
