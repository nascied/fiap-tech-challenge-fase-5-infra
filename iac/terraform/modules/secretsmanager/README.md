## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.44.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.44.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_secretsmanager_secret.donation_service](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.ngo_service](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.volunteer_service](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.donation_service](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.ngo_service](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.volunteer_service](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/secretsmanager_secret_version) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_access_key_id"></a> [aws\_access\_key\_id](#input\_aws\_access\_key\_id) | n/a | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | n/a | yes |
| <a name="input_aws_secret_access_key"></a> [aws\_secret\_access\_key](#input\_aws\_secret\_access\_key) | n/a | `string` | n/a | yes |
| <a name="input_aws_session_token"></a> [aws\_session\_token](#input\_aws\_session\_token) | n/a | `string` | n/a | yes |
| <a name="input_donation_database_url"></a> [donation\_database\_url](#input\_donation\_database\_url) | Connection string do RDS do donation-service (module.db, índice do donation-service) | `string` | n/a | yes |
| <a name="input_donation_sqs_queue_url"></a> [donation\_sqs\_queue\_url](#input\_donation\_sqs\_queue\_url) | URL da fila SQS usada pelo donation-service (module.sqs) | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefixo dos nomes de secret (ex.: fiap-tc-f5) | `string` | n/a | yes |
| <a name="input_ngo_database_url"></a> [ngo\_database\_url](#input\_ngo\_database\_url) | Connection string do RDS do ngo-service (module.db, índice do ngo-service) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_donation_service_secret_arn"></a> [donation\_service\_secret\_arn](#output\_donation\_service\_secret\_arn) | ARN do secret do donation-service no Secrets Manager |
| <a name="output_donation_service_secret_name"></a> [donation\_service\_secret\_name](#output\_donation\_service\_secret\_name) | Nome do secret do donation-service no Secrets Manager |
| <a name="output_ngo_service_secret_arn"></a> [ngo\_service\_secret\_arn](#output\_ngo\_service\_secret\_arn) | ARN do secret do ngo-service no Secrets Manager |
| <a name="output_ngo_service_secret_name"></a> [ngo\_service\_secret\_name](#output\_ngo\_service\_secret\_name) | Nome do secret do ngo-service no Secrets Manager |
| <a name="output_volunteer_service_secret_arn"></a> [volunteer\_service\_secret\_arn](#output\_volunteer\_service\_secret\_arn) | ARN do secret do volunteer-service no Secrets Manager |
| <a name="output_volunteer_service_secret_name"></a> [volunteer\_service\_secret\_name](#output\_volunteer\_service\_secret\_name) | Nome do secret do volunteer-service no Secrets Manager |
