## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.44.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.44.0 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/backup_selection) | resource |
| [aws_backup_vault.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/backup_vault) | resource |
| [aws_backup_vault_notifications.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/backup_vault_notifications) | resource |
| [aws_s3_bucket_lifecycle_configuration.velero](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.velero](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.velero](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/s3_bucket_versioning) | resource |
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/sns_topic_subscription) | resource |
| [null_resource.velero_bucket](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/data-sources/caller_identity) | data source |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/data-sources/iam_role) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_notification_email"></a> [notification\_email](#input\_notification\_email) | E-mail para notificação de falha/sucesso de backup e restore. Vazio desativa a inscrição SNS | `string` | `""` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Dias de retenção dos recovery points no vault | `number` | `7` | no |
| <a name="input_schedule_cron"></a> [schedule\_cron](#input\_schedule\_cron) | Expressão cron (formato AWS Backup) de agendamento do backup | `string` | `"cron(0 6 * * ? *)"` | no |
| <a name="input_selection_tag_key"></a> [selection\_tag\_key](#input\_selection\_tag\_key) | Chave da tag usada para selecionar recursos a proteger | `string` | `"Backup"` | no |
| <a name="input_selection_tag_value"></a> [selection\_tag\_value](#input\_selection\_tag\_value) | Valor da tag usada para selecionar recursos a proteger | `string` | `"true"` | no |
| <a name="input_vault_name"></a> [vault\_name](#input\_vault\_name) | Nome do AWS Backup vault | `string` | n/a | yes |
| <a name="input_velero_bucket_name"></a> [velero\_bucket\_name](#input\_velero\_bucket\_name) | Nome do bucket S3 usado pelo Velero para armazenar backups do cluster EKS | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backup_plan_arn"></a> [backup\_plan\_arn](#output\_backup\_plan\_arn) | ARN do plano de backup |
| <a name="output_backup_plan_id"></a> [backup\_plan\_id](#output\_backup\_plan\_id) | ID do plano de backup |
| <a name="output_backup_vault_arn"></a> [backup\_vault\_arn](#output\_backup\_vault\_arn) | ARN do AWS Backup vault |
| <a name="output_backup_vault_name"></a> [backup\_vault\_name](#output\_backup\_vault\_name) | Nome do AWS Backup vault |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | ARN do tópico SNS de notificação de jobs de backup/restore |
| <a name="output_velero_bucket_arn"></a> [velero\_bucket\_arn](#output\_velero\_bucket\_arn) | ARN do bucket S3 usado pelo Velero |
| <a name="output_velero_bucket_name"></a> [velero\_bucket\_name](#output\_velero\_bucket\_name) | Nome do bucket S3 usado pelo Velero |
