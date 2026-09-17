data "archive_file" "bridge" {
  type        = "zip"
  source_file = "${path.module}/src/bridge.py"
  output_path = "${path.module}/dist/bridge.zip"
}

resource "aws_lambda_function" "bridge" {
  function_name = var.function_name
  role          = data.aws_iam_role.this.arn
  handler       = "bridge.handler"
  runtime       = "python3.11"
  timeout       = 15
  memory_size   = 128

  filename         = data.archive_file.bridge.output_path
  source_code_hash = data.archive_file.bridge.output_base64sha256

  environment {
    variables = {
      GITHUB_REPO              = var.github_repo
      GITHUB_TOKEN             = var.github_token
      PAGERDUTY_WEBHOOK_SECRET = var.pagerduty_webhook_secret
    }
  }
}

# Function URL — endpoint público HTTPS simples, sem precisar de API Gateway.
# Autenticação real é feita dentro do handler (verificação de assinatura do
# PagerDuty), não pelo IAM da URL — o PagerDuty não sabe assinar SigV4.
resource "aws_lambda_function_url" "bridge" {
  function_name      = aws_lambda_function.bridge.function_name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "bridge" {
  name              = "/aws/lambda/${aws_lambda_function.bridge.function_name}"
  retention_in_days = 14
}
