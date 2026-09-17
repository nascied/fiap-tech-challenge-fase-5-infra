output "function_url" {
  description = "URL pública HTTPS da Lambda — configurar como destino da subscription de webhook V3 no PagerDuty"
  value       = aws_lambda_function_url.bridge.function_url
}

output "function_name" {
  value = aws_lambda_function.bridge.function_name
}

output "function_arn" {
  value = aws_lambda_function.bridge.arn
}
