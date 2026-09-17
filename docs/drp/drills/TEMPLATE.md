# Drill de DRP — Template

Copie este arquivo para `AAAA-MM-DD-<componente>.md` a cada simulado (ex.: `2026-08-23-donation-rds.md`).

## Metadados

| Campo | Valor |
|---|---|
| Data | |
| Componente testado | RDS `donation_db` / RDS `ngo_db` / DynamoDB `SolidaryTechVolunteers` / EKS+Velero (namespace) / EKS+Velero (cluster completo) |
| Runbook seguido | link |
| Executor(es) | |
| Cenário simulado | ex.: "DELETE acidental na tabela donations", "namespace apagado com kubectl" |

## Linha do tempo

| Horário | Evento |
|---|---|
| T0 | Início do incidente simulado |
| | Runbook iniciado |
| | Restore concluído |
| | Cutover concluído |
| | Smoke test passou |

## Resultado

- **RTO estimado no DRP.md:** 
- **RTO real observado:** 
- **RPO real observado** (quanto de dado ficou entre o último backup/PITR usável e o ponto simulado do incidente): 

## O que travou / desviou do runbook

Liste qualquer passo que precisou de improviso, comando que falhou, permissão que faltou, etc. — isso é o que justifica atualizar o runbook depois.

## Ações de melhoria

- [ ]
- [ ]

## O runbook precisa ser atualizado?

- [ ] Não, seguiu exatamente como documentado
- [ ] Sim — já atualizado neste PR/commit
- [ ] Sim — pendente (abrir issue/registrar aqui o motivo)
