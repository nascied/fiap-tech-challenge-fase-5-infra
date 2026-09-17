# module.lambda — ponte PagerDuty -> GitHub Actions

Provisiona a única peça de infraestrutura nova do fluxo de self-healing
descrito em [`aiops/README.md`](../../../../aiops/README.md): uma função
Lambda pequena (só stdlib, sem dependências) cujo único trabalho é receber o
webhook V3 (`incident.triggered`) do PagerDuty, verificar a assinatura, e
disparar um `repository_dispatch` no GitHub — toda a análise/decisão de
self-healing roda no GitHub Action, não aqui.

## Recursos

- `aws_lambda_function` — runtime Python 3.11, role reaproveitando a `LabRole`
  (conta AWS Academy não permite IAM role própria, mesmo padrão de
  `modules/backup/data.tf`).
- `aws_lambda_function_url` — endpoint HTTPS público, sem API Gateway.
  Autenticação real acontece dentro do handler (assinatura do PagerDuty), não
  no nível da URL (`authorization_type = "NONE"` porque o PagerDuty não sabe
  assinar requisições SigV4).
- `aws_cloudwatch_log_group` — retenção de 14 dias.

## Depois do `apply`

1. Pegue o output `function_url`.
2. No painel do PagerDuty, crie uma "Webhook Subscription" (V3) apontando
   pra essa URL, escopo "incident.triggered" no serviço do `donation-service`
   (hoje é o único que gera `severity: critical`, ver
   `alerting/prometheusrule-slo-burn.yaml`).
3. Copie o secret de verificação de assinatura que o PagerDuty gera na hora de
   criar a subscription pra dentro de `var.pagerduty_webhook_secret`
   (`TF_VAR_pagerduty_webhook_secret`, nunca em `.tfvars`) — se o valor já
   tiver sido aplicado antes de existir o secret real, rode `terraform apply`
   de novo depois de criar a subscription.
4. Use o botão de "enviar webhook de teste" do PagerDuty pra validar a ponta a
   ponta antes de depender disso num incidente real — é também a única forma
   prática de confirmar o formato exato da assinatura, que não foi validado
   contra a documentação ao vivo (ver `aiops/README.md`, seção "O que NÃO está
   confirmado").

## Variáveis sensíveis

`github_token` e `pagerduty_webhook_secret` não têm default e nunca devem ir
em `.tfvars` — mesmo padrão já usado pelas credenciais AWS Academy em
`variable.tf` da raiz.

- **Pela pipeline** (`.github/workflows/terraform.yml`): resolvidas
  automaticamente via `TF_VAR_github_token`/`TF_VAR_pagerduty_webhook_secret`
  no `env:` do job, a partir dos secrets do repositório
  `INCIDENT_BRIDGE_GITHUB_TOKEN`/`PAGERDUTY_WEBHOOK_SECRET` (`Settings >
  Secrets and variables > Actions`) — nunca em texto plano em lugar nenhum do
  repositório.
- **Rodando localmente** (`scripts/05-plan.sh`/`06-apply.sh`): não há
  script que resolva essas duas (diferente das credenciais AWS, que são
  resolvidas automaticamente) — exporte `TF_VAR_github_token`/
  `TF_VAR_pagerduty_webhook_secret` manualmente no shell antes de rodar.
