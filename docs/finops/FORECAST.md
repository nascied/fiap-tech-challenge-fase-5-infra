# 💰 Relatório de Forecast — Custos Mensais

> Requisito do Hackathon Fase 5 (seção *FinOps: Otimização Financeira e Tagueamento*): *"crie uma projeção (Forecast) de custos mensais da arquitetura. Indique pelo menos uma recomendação prática de otimização nativa de nuvem."*

## Premissas

- **Preços on-demand de lista pública da AWS**, região `us-east-1`, sem desconto de Reserved Instance/Savings Plan — a conta AWS Academy (Learner Lab) usada neste projeto **não permite comprar** RI/Savings Plan nem tem acesso ao console de Billing, então esta projeção representa **o que a mesma arquitetura custaria numa conta de produção real**, não o consumo de créditos de laboratório.
- Considera **um único ambiente ativo 24/7** durante o mês (`dev` **ou** `prd`, não os dois simultaneamente — a conta Academy é single-account, então rodar os dois ao mesmo tempo colidiria em nomes de recursos únicos globalmente, como já documentado).
- Tráfego estimado como **carga de demonstração/hackathon**, não produção real com milhares de usuários simultâneos.
- Baseado nos recursos efetivamente definidos no Terraform deste repositório na data deste relatório (2026-08). **Não inclui ElastiCache Redis** — o `module.cache` foi removido do provisionamento (ver seção "Otimizações aplicadas" abaixo), então nunca chega a ser criado.

## Custo por recurso

| Recurso | Módulo | Configuração provisionada | Custo estimado/mês |
|---|---|---|---:|
| EKS control plane | `eks` | 1 cluster gerenciado | US$ 73,00 |
| EC2 (node group) | `eks` | 3× `t3.medium` on-demand — **teto de capacidade** (`min_size=1`/`max_size=6`/`desired_size` dinâmico via Cluster Autoscaler, ver seção "Otimizações aplicadas") | US$ 91,10 |
| EBS (root volumes) | `eks` | 3× ~20 GB gp3 (default do node group) | US$ 4,80 |
| NAT Gateway | `vpc` | 1× + processamento de dados | US$ 33,30 |
| Elastic IP | `vpc` | 1× (associado ao NAT Gateway) | US$ 3,65 |
| RDS PostgreSQL (compute) | `rds` | 2× `db.t3.micro` Single-AZ (`donation-service`, `ngo-service`) | US$ 24,82 |
| RDS PostgreSQL (storage) | `rds` | 2× 20 GB gp2 | US$ 4,60 |
| DynamoDB | `dynamodb` | `PAY_PER_REQUEST`, tráfego de demo | ~US$ 1,00 |
| SQS | `sqs` | Standard queue, tráfego de demo | US$ 0,00 (dentro do free tier permanente de 1M req/mês) |
| ECR | `ecr` | 3 repositórios, poucas imagens versionadas | ~US$ 0,20 |
| AWS Backup | `backup` | vault, retenção de 7 dias (RDS + DynamoDB) | ~US$ 1,00 |
| S3 (Velero) | `backup` | bucket versionado, poucos GB de manifests/snapshots | ~US$ 0,50 |
| SNS | `backup` | notificações de job de backup/restore | US$ 0,00 (dentro do free tier) |
| Lambda (`incident-bridge`, ITSM/AIOps) | `lambda` | Invocações esporádicas (self-healing) + Function URL | US$ 0,00 (dentro do free tier) |
| **Total estimado (teto de capacidade, 3 nodes)** | | | **≈ US$ 238,00/mês** |
| **Total observado na prática (2 nodes, Cluster Autoscaler ativo)** | | | **≈ US$ 207,60/mês** |

> Valores de lista pública AWS, arredondados. Não é uma cotação — é uma ordem de grandeza para orçamento e priorização de otimização. O "teto de capacidade" é o pior caso orçamentário (carga alta, autoscaler no `max_size`); o "observado na prática" é o gasto real medido nesta sessão com a carga de demonstração do hackathon.

## Maiores contribuintes de custo

| # | Recurso | % do total |
|---|---|---:|
| 1 | EC2 (node group EKS) | ~38% |
| 2 | EKS control plane | ~31% |
| 3 | NAT Gateway | ~14% |
| 4 | RDS (compute + storage) | ~12% |
| — | Demais (DynamoDB, ECR, Backup, S3, EIP, SNS, SQS) | ~5% |

O cluster EKS sozinho (control plane + nodes + EBS) responde por **~71% da fatura no teto de capacidade** (e ~66% no cenário observado na prática, já com o Cluster Autoscaler reduzindo o node group) — continua sendo o ponto de maior alavancagem para qualquer otimização.

## Otimizações aplicadas

### ✅ Remoção do ElastiCache Redis não utilizado — economia de US$ 12,41/mês (100% do custo do recurso)

Nenhum dos três microsserviços do projeto (`ngo-service`, `donation-service`, `volunteer-service`) usa Redis — conferido diretamente no código-fonte (`app.py`/`main.go` de cada serviço, nenhum importa cliente Redis). O `module "cache"` (`./modules/redis`) era resíduo do projeto anterior (Fase 3, que tinha um `evaluation-service` com cache) e **foi removido de `main.tf`** — o custo já não existe mais na tabela acima. O código do módulo continua em `modules/redis/` (não referenciado por nenhum `module` block) caso um serviço futuro precise de cache. Era a otimização de maior retorno imediato porque não tinha trade-off de performance a avaliar — era custo sem função.

### ✅ Rightsizing do node group EKS via Cluster Autoscaler — confirmado em produção, não é mais só uma recomendação

`module.cluster_autoscaler` (`modules/cluster-autoscaler`, Helm, sem IRSA — reaproveita a `LabRole` via IMDS, mesmo padrão do `module.velero`) está **instalado e rodando de verdade** no cluster (`helm list -n kube-system`: release `cluster-autoscaler` `deployed`). O `aws_eks_node_group` deixou de ter `desired_size` fixo em 3 — o ASG subjacente agora tem `min_size=1`/`max_size=6`, com o Cluster Autoscaler ajustando o `desired_size` sozinho conforme a carga real.

**Evidência real, medida nesta sessão, não estimativa**: `kubectl get nodes` no cluster de produção confirma **2 nodes `t3.medium` ativos** (reduzido de 3 sozinho, sem nenhuma intervenção manual, pela baixa utilização detectada) — economia real e já em curso de **~US$ 30,37/mês** (1 node `t3.medium` a menos), podendo cair ainda mais se a carga permitir chegar perto do `min_size=1`. Sob carga real de pico, o autoscaler sobe de volta até `max_size=6` automaticamente — a otimização não sacrifica capacidade disponível, só remove o desperdício de pagar por capacidade ociosa. É a resposta direta ao item "Rightsizing" pedido na mesma seção do enunciado do hackathon, e a única otimização deste documento com prova operacional ao vivo (não apenas projeção).

## Recomendações de otimização nativa de nuvem (pendentes)

### 1. Desligar o ambiente `dev` fora de janelas de uso

Já documentado nas [Boas Práticas](../../README.md#boas-práticas) deste repositório (`terraform destroy` em ambientes temporários). Como este projeto roda em conta AWS Academy com sessão de poucas horas, isso já acontece naturalmente entre sessões de estudo — mas vale disciplina deliberada: um ambiente `dev` esquecido rodando 24/7 sem uso é ~US$ 238/mês jogados fora.

## Nota — recursos temporários de teste de DR (fora deste Forecast)

Testes reais de disaster recovery cross-region (`us-west-2`, ver `docs/drp/`) criam, sob demanda (`scripts/dr-test-*.sh`), um cluster EKS mínimo + RDS/DynamoDB restaurados — custo real de ~US$ 0,18–0,20/hora enquanto ficam de pé. **Não faz parte deste Forecast de regime permanente** — é uma despesa pontual de validação, desmontada ao final do teste (`dr-test-destroy*.sh`), não um custo recorrente da arquitetura.

## Metodologia

Preços consultados na tabela pública da AWS (on-demand, `us-east-1`) em 2026-08. Evidência do Cluster Autoscaler (seção "Otimizações aplicadas") medida ao vivo em 2026-09-27. Não inclui: Reserved Instances/Savings Plans (indisponíveis na conta Academy), custo de transferência de dados de saída para a internet (variável com tráfego real de usuários, não estimável para uma demo), nem custo de observabilidade (fora do escopo deste repositório de IaC).
