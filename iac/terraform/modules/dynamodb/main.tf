resource "aws_dynamodb_table" "this" {
  name         = var.aws_dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "volunteer_id"

  attribute {
    name = "volunteer_id"
    type = "S"
  }

  # Point-in-time recovery nativo: restauração a qualquer segundo dentro dos
  # últimos 35 dias, sem custo de setup e sem depender do AWS Backup.
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name    = "${local.resource_prefix_name}-${var.aws_dynamodb_table_name}"
    Backup  = "true" # usada pelo module.backup (aws_backup_selection por tag)
    Service = "volunteer-service"
    Tier    = "1"
  }
}