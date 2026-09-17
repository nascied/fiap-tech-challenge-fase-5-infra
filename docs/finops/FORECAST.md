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
| EC2 (node group) | `eks` | 3× `t3.medium` on-demand, `desired_size=3`/`max_size=3` | US$ 91,10 |
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
| **Total estimado** | | | **≈ US$ 238,00/mês** |

> Valores de lista pública AWS, arredondados. Não é uma cotação — é uma ordem de grandeza para orçamento e priorização de otimização.

## Maiores contribuintes de custo

| # | Recurso | % do total |
|---|---|---:|
| 1 | EC2 (node group EKS) | ~38% |
| 2 | EKS control plane | ~31% |
| 3 | NAT Gateway | ~14% |
| 4 | RDS (compute + storage) | ~12% |
| — | Demais (DynamoDB, ECR, Backup, S3, EIP, SNS, SQS) | ~5% |

O cluster EKS sozinho (control plane + nodes + EBS) responde por **~71% da fatura** — é o ponto de maior alavancagem para qualquer otimização.

## Otimizações aplicadas

### ✅ Remoção do ElastiCache Redis não utilizado — economia de US$ 12,41/mês (100% do custo do recurso)

Nenhum dos três microsserviços do projeto (`ngo-service`, `donation-service`, `volunteer-service`) usa Redis — conferido diretamente no código-fonte (`app.py`/`main.go` de cada serviço, nenhum importa cliente Redis). O `module "cache"` (`./modules/redis`) era resíduo do projeto anterior (Fase 3, que tinha um `evaluation-service` com cache) e **foi removido de `main.tf`** — o custo já não existe mais na tabela acima. O código do módulo continua em `modules/redis/` (não referenciado por nenhum `module` block) caso um serviço futuro precise de cache. Era a otimização de maior retorno imediato porque não tinha trade-off de performance a avaliar — era custo sem função.

## Recomendações de otimização nativa de nuvem (pendentes)

### 1. Rightsizing do node group EKS via Cluster Autoscaler — economia potencial de até US$ 60/mês

O `aws_eks_node_group` está fixo em `desired_size = 3` / `max_size = 3` (`modules/eks/main.tf`), sem nenhum autoscaler configurado — o cluster paga por 3 nodes `t3.medium` o mês inteiro, independente da carga real, que para uma demonstração de hackathon é mínima na maior parte do tempo. Habilitar o **Cluster Autoscaler** (nativo do ecossistema Kubernetes/EKS, sem custo de licença) e reduzir `min_size` para 1 permite o cluster escalar para baixo fora de pico e voltar a 3 nodes sob carga real, automaticamente — ataca diretamente o maior item da fatura (EC2 é ~38% do total) sem sacrificar capacidade quando ela é necessária. É também a resposta direta ao item "Rightsizing" pedido na mesma seção do enunciado do hackathon.

### 2. Complementar: desligar o ambiente `dev` fora de janelas de uso

Já documentado nas [Boas Práticas](../../README.md#boas-práticas) deste repositório (`terraform destroy` em ambientes temporários). Como este projeto roda em conta AWS Academy com sessão de poucas horas, isso já acontece naturalmente entre sessões de estudo — mas vale disciplina deliberada: um ambiente `dev` esquecido rodando 24/7 sem uso é ~US$ 238/mês jogados fora.

## Metodologia

Preços consultados na tabela pública da AWS (on-demand, `us-east-1`) em 2026-08. Não inclui: Reserved Instances/Savings Plans (indisponíveis na conta Academy), custo de transferência de dados de saída para a internet (variável com tráfego real de usuários, não estimável para uma demo), nem custo de observabilidade (fora do escopo deste repositório de IaC).
