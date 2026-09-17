output "sqs_queue_url" {
  description = "URL da fila SQS"
  value       = aws_sqs_queue.this.url
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS"
  value       = aws_sqs_queue.this.arn
}

output "sqs_queue_name" {
  description = "Nome da fila SQS"
  value       = aws_sqs_queue.this.name
}
