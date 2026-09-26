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
```

## O que os scripts NÃO fazem

- Não guardam nem comitam credencial nenhuma.
- Não rodam `apply`/`destroy` sem confirmação interativa.
- Não substituem o `.github/workflows/terraform.yml` — esse arquivo ainda é resíduo do projeto anterior (ToggleMaster/Fase 3, nomes de serviço errados, Redis, repo de destino errado) e precisa de ajuste separado antes de virar o pipeline de CI real.
