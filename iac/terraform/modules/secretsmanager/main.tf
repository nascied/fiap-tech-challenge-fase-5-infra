#
# Secrets consumidos via Secrets Store CSI Driver (provider AWS) pelos charts
# no repositório GitOps — ver helm/{ngo,donation}-service/templates/
# secretproviderclass.yaml.
#
# ngo-service é o único que não acessa nenhum outro recurso AWS (só Postgres)
# — o secret dele existe só pra sincronizar o DATABASE_URL real do RDS (com a
# senha aleatória compartilhada) automaticamente, em vez de deixar isso como
# placeholder manual no values.yaml do Helm.
#
# recovery_window_in_days = 0 em todos: sem isso, um "terraform destroy"
# deixa o nome do secret "agendado pra deleção" (padrão AWS: 30 dias de
# recovery window) e o "apply" seguinte falha com InvalidRequestException
# ("already scheduled for deletion") até alguém rodar um
# force-delete-without-recovery manual. Ambiente de hackathon com
# destroy/apply frequente não precisa dessa rede de segurança.
#
# Sem credenciais AWS estáticas (AWS_ACCESS_KEY_ID/etc.) em nenhum secret:
# removidas numa sessão posterior depois de confirmar EMPIRICAMENTE (pod real
# no cluster, sem ServiceAccount/CSI nenhum) que a cadeia padrão de credenciais
# do SDK já resolve via IMDS -> instance profile do node -> LabRole, com
# "aws sts get-caller-identity" e uma chamada real ao SQS funcionando sem
# nenhuma credencial explícita. Essas variáveis nunca foram necessárias pro
# código (session.NewSession()/boto3.resource() já usavam o default credential
# chain), mas foram mantidas por uma decisão explícita anterior do usuário —
# revertida nesta sessão à luz do teste real. module.velero já usava esse
# mesmo caminho (LabRole via IMDS) desde o início.
#
# volunteer-service não tem mais NENHUM secret aqui: sem as credenciais AWS,
# não sobra nada que precise vir do Secrets Manager (AWS_REGION/
# AWS_DYNAMODB_TABLE já vêm do ConfigMap do chart, não do Secret) — o que
# também elimina a necessidade de ServiceAccount/CSI Driver/IRSA-Pod-Identity
# pra esse serviço (ver módulo velero pro mesmo padrão de fallback via IMDS).

resource "aws_secretsmanager_secret" "donation_service" {
  name                    = "${var.name_prefix}-donation-service"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "donation_service" {
  secret_id = aws_secretsmanager_secret.donation_service.id
  secret_string = jsonencode({
    DATABASE_URL = var.donation_database_url
    AWS_REGION   = var.aws_region
    AWS_SQS_URL  = var.donation_sqs_queue_url
  })
}

resource "aws_secretsmanager_secret" "ngo_service" {
  name                    = "${var.name_prefix}-ngo-service"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ngo_service" {
  secret_id = aws_secretsmanager_secret.ngo_service.id
  secret_string = jsonencode({
    DATABASE_URL = var.ngo_database_url
  })
}

