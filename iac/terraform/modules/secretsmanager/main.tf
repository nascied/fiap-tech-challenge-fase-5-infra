#
# Secrets consumidos via Secrets Store CSI Driver (provider AWS) pelos 3 charts
# no repositório GitOps — ver helm/{ngo,donation,volunteer}-service/templates/
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

resource "aws_secretsmanager_secret" "donation_service" {
  name                    = "${var.name_prefix}-donation-service"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "donation_service" {
  secret_id = aws_secretsmanager_secret.donation_service.id
  secret_string = jsonencode({
    DATABASE_URL          = var.donation_database_url
    AWS_REGION            = var.aws_region
    AWS_SQS_URL           = var.donation_sqs_queue_url
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    AWS_SESSION_TOKEN     = var.aws_session_token
  })
}

resource "aws_secretsmanager_secret" "volunteer_service" {
  name                    = "${var.name_prefix}-volunteer-service"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "volunteer_service" {
  secret_id = aws_secretsmanager_secret.volunteer_service.id
  secret_string = jsonencode({
    AWS_REGION            = var.aws_region
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    AWS_SESSION_TOKEN     = var.aws_session_token
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

