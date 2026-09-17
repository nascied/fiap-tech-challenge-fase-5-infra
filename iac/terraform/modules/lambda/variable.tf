variable "function_name" {
  description = "Nome da função Lambda (ponte PagerDuty -> GitHub Actions)"
  type        = string
  default     = "fiap-tc-f5-incident-bridge"
}

variable "github_repo" {
  description = "Repositório GitHub (owner/repo) que recebe o repository_dispatch"
  type        = string
}

# Sensível: token de acesso pessoal (fine-grained, escopo mínimo "contents:
# read/write" ou "actions: write" só nesse repo) usado pra disparar o
# repository_dispatch. Nunca versionar em .tfvars — passar via TF_VAR_github_token.
variable "github_token" {
  description = "Token do GitHub com permissão de repository_dispatch no repo acima"
  type        = string
  sensitive   = true
}

# Sensível: secret usado pra verificar a assinatura do webhook do PagerDuty
# (header x-pagerduty-signature). Mesmo valor configurado na subscription do
# webhook V3 no painel do PagerDuty. Nunca versionar em .tfvars.
variable "pagerduty_webhook_secret" {
  description = "Secret de verificação de assinatura da subscription de webhook V3 do PagerDuty"
  type        = string
  sensitive   = true
}
