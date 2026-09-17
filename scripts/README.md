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
| 5 | `05-plan.sh <dev\|prd>` | `terraform plan`, salva em `iac/terraform/tfplan` | Sim |
| 6 | `06-apply.sh <dev\|prd>` | Aplica o `tfplan` salvo, com confirmação interativa | Sim |
| 7 | `07-update-kubeconfig.sh` | `aws eks update-kubeconfig` + `kubectl get nodes`, usando o nome do cluster do `terraform output` | Sim |
| 8 | `08-destroy.sh <dev\|prd>` | `terraform destroy`, com dupla confirmação (nome do ambiente + revisão do plano) | Sim |
| — | `run-all.sh <dev\|prd>` | Roda 0→7 em sequência | Sim |

`lib/common.sh` concentra as funções compartilhadas (log/warn/die, validação de ambiente, checagem de sessão, injeção de credenciais como `TF_VAR_*`) — não é executado direto.

## Credenciais AWS Academy → `TF_VAR_*`

`var.aws_access_key_id`/`aws_secret_access_key`/`aws_session_token` (usadas por `module.secrets` para popular o Secrets Manager, ver `iac/terraform/variable.tf`) **não têm default e não devem ir em `.tfvars`**. Os scripts que precisam delas (`05-plan.sh`, `08-destroy.sh`) resolvem a sessão atual com `aws configure export-credentials` e exportam como `TF_VAR_aws_access_key_id` etc. na hora — nada é escrito em disco. Se a sessão expirar no meio do trabalho, reexporte as credenciais da AWS Academy no shell e rode o script de novo.

**`var.github_token`/`var.pagerduty_webhook_secret` (module.incident_bridge) não são cobertas por nenhum script** — diferente das credenciais AWS acima, que são resolvidas automaticamente. Rodando localmente (em vez de pela pipeline `.github/workflows/terraform.yml`, que já resolve as duas via os secrets `INCIDENT_BRIDGE_GITHUB_TOKEN`/`PAGERDUTY_WEBHOOK_SECRET` do repositório), exporte manualmente antes de `05-plan.sh`/`06-apply.sh`:

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
