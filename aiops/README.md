# aiops/ — Self-healing de incidentes (ITSM/AIOps, Requisito 3)

Fecha o ciclo de detecção → resposta automatizada do `docs/itsm-aiops.md`
(repo `fiap-tech-challenge-fase-5-observability`): quando um alerta crítico
vira incidente no PagerDuty, um agente com Claude decide se um restart do
serviço afetado resolve o sintoma e, se decidir que sim, executa de verdade.

## Fluxo completo

```
Prometheus (PrometheusRule de burn rate)
  -> Alertmanager (severity="critical", hoje só donation-service)
       -> pagerduty_configs (routing key, ver values/kube-prometheus-stack.yaml)
            -> PagerDuty cria o incidente
                 -> Webhook V3 (incident.triggered) -> Lambda-ponte
                      (iac/terraform/modules/lambda) reformata o payload e
                      chama a API do GitHub (repository_dispatch)
                        -> .github/workflows/incident-response.yml
                             -> aiops/incident_response.py (este diretório)
                                  1. extrai qual serviço está envolvido
                                  2. pede pro Claude (Sonnet 5) decidir se
                                     um restart resolve, com tool-use
                                  3. se decidir que sim: kubectl rollout
                                     restart no Deployment certo
                                  4. posta o resultado no Slack
                                  5. resolve o incidente no PagerDuty
```

**Por que uma ponte Lambda e não PagerDuty -> GitHub direto?** O endpoint
`repository_dispatch` do GitHub exige um corpo específico
(`{"event_type": ..., "client_payload": {...}}`) e autenticação via token —
o webhook nativo do PagerDuty não manda esse formato. A ponte só reformata e
repassa; toda a decisão fica no GitHub Action, não na Lambda.

**Por que a ponte roda fora do EKS (Lambda, não um pod no cluster)?** Se o
próprio cluster é o que está com problema, um receptor rodando dentro dele
pode não estar disponível pra receber o webhook. Rodar fora do EKS evita essa
dependência circular.

## Autonomia

Execução **automática em todos os tiers** (decisão do usuário, ver histórico
da sessão) — o script não espera aprovação humana antes de rodar o
`kubectl rollout restart`. O Claude ainda decide *se* vale a pena reiniciar
(não reinicia cegamente todo incidente); a auditoria de cada decisão fica no
log estruturado (stdout do GitHub Actions) e na mensagem do Slack.

## O que NÃO está confirmado (verificar antes de produção)

A documentação do PagerDuty é renderizada via JavaScript e as tentativas de
`WebFetch` desta sessão não conseguiram extrair o conteúdo — dois pontos do
código foram implementados com o formato mais estabelecido que se conhece,
mas **sem confirmação ao vivo contra a doc oficial**:

1. **Verificação de assinatura do webhook** (`x-pagerduty-signature`,
   `iac/terraform/modules/lambda/src/bridge.py`) — o header existe (confirmado
   via `support.pagerduty.com`), mas o algoritmo/formato exato do valor não
   foi confirmado.
2. **Resolução do incidente via REST API** (`PUT /incidents/{id}`,
   `resolve_pagerduty_incident()` em `incident_response.py`) — formato padrão
   da API v2 do PagerDuty, não testado contra uma conta real.

Testar os dois assim que houver uma conta PagerDuty real disponível — o
PagerDuty tem um botão de "enviar webhook de teste" na tela de configuração
da subscription, útil pra validar (1) sem esperar um incidente real.

## Testar localmente (sem PagerDuty, GitHub Actions ou EKS reais)

```bash
pip install -r aiops/requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...

# dry-run: não executa kubectl nem chama PagerDuty/Slack de verdade
python aiops/incident_response.py \
  --payload-file aiops/fixtures/sample_incident.json \
  --dry-run
```

Isso exercita o fluxo completo (extrai o serviço do payload, chama o Claude
com tool-use, decide, e só *loga* o que faria) — dá pra validar o
comportamento do agente sem precisar de nenhuma infra real. Sem `--dry-run`
(e com um kubeconfig configurado), o restart é executado de verdade.

> Nesta sessão de desenvolvimento, o sandbox não tinha `pip`/`anthropic`
> instalável, então só a lógica pura (parsing do payload, allowlist de
> serviços, execução em dry-run) foi testada de verdade aqui — validado com
> um stub do pacote `anthropic`. A chamada real à API do Claude precisa ser
> testada com uma chave de verdade antes de confiar nisso em produção.

## Secrets do GitHub Actions (`.github/workflows/incident-response.yml`)

Além das variáveis que `incident_response.py` lê diretamente (tabela abaixo),
o workflow em si precisa destes Secrets configurados no repositório
(Settings → Secrets and variables → Actions):

| Secret | Uso |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` | Sessão AWS Academy — mesma limitação de ~4h documentada em `scripts/README.md`. Precisa estar válida no momento em que o incidente dispara. |
| `EKS_CLUSTER_NAME` | Nome do cluster (`terraform output -raw aws_eks_cluster_name` depois do `apply`) — usado no `aws eks update-kubeconfig`. |
| `ANTHROPIC_API_KEY` | Chamada à API do Claude. |
| `INCIDENT_SLACK_WEBHOOK_URL` | Notificação do resultado — opcional, workflow segue sem ele. |
| `PAGERDUTY_API_TOKEN` / `PAGERDUTY_FROM_EMAIL` | Resolver o incidente automaticamente — opcional. |

Também é preciso, no repo de infra (Terraform), `var.github_token`/
`var.pagerduty_webhook_secret` de `module.incident_bridge` — resolvidas
automaticamente pela pipeline (`.github/workflows/terraform.yml`) a partir
dos secrets `INCIDENT_BRIDGE_GITHUB_TOKEN`/`PAGERDUTY_WEBHOOK_SECRET` do
repositório; rodando localmente via `scripts/`, precisam ser exportadas
manualmente como `TF_VAR_github_token`/`TF_VAR_pagerduty_webhook_secret` antes
do `apply` — ver `iac/terraform/modules/lambda/README.md`.

## Variáveis de ambiente

| Variável | Obrigatória | Uso |
|---|---|---|
| `ANTHROPIC_API_KEY` | sim | Chamada à API do Claude |
| `INCIDENT_PAYLOAD` | sim (exceto com `--payload-file`) | JSON do `client_payload` do `repository_dispatch` |
| `INCIDENT_SLACK_WEBHOOK_URL` | não | Se ausente, só loga que pularia o Slack |
| `PAGERDUTY_API_TOKEN` | não | Resolver o incidente automaticamente (REST API) |
| `PAGERDUTY_FROM_EMAIL` | não | Header `From` exigido pela REST API do PagerDuty |

Sem `PAGERDUTY_API_TOKEN`/`PAGERDUTY_FROM_EMAIL`, o restart ainda acontece —
só o fechamento automático do incidente no PagerDuty é pulado (fica pra
alguém fechar manualmente).

## Allowlist de serviços (segurança)

`ALLOWED_SERVICES` em `incident_response.py` é a única lista de
serviços/Deployments que esse agente pode tocar — tanto o `enum` da tool
(schema `strict: true`) quanto uma segunda checagem em `execute_restart()`
antes de montar o comando `kubectl`. O Claude nunca decide um nome de
Deployment livre; só escolhe entre os 3 valores dessa lista.
