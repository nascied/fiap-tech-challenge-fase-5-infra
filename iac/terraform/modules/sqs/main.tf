
# ============================================================
# SQS QUEUE PADRÃO (FIAP)
# ============================================================

resource "aws_sqs_queue" "this" {
  name                      = var.aws_sqs_queue_name
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 20


  tags = {
    Name    = "${local.resource_prefix_name}-sqs-${var.aws_sqs_queue_name}"
    Service = "donation-service" # fila do fluxo de doação (Hot Path)
    Tier    = "0"
  }
}