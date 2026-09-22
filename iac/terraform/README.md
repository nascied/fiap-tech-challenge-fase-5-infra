## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.44.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ./modules/argocd | n/a |
| <a name="module_backup"></a> [backup](#module\_backup) | ./modules/backup | n/a |
| <a name="module_db"></a> [db](#module\_db) | ./modules/rds | n/a |
| <a name="module_dynamodb"></a> [dynamodb](#module\_dynamodb) | ./modules/dynamodb | n/a |
| <a name="module_ecr"></a> [ecr](#module\_ecr) | ./modules/ecr | n/a |
| <a name="module_eks"></a> [eks](#module\_eks) | ./modules/eks | n/a |
| <a name="module_incident_bridge"></a> [incident\_bridge](#module\_incident\_bridge) | ./modules/lambda | n/a |
| <a name="module_secrets"></a> [secrets](#module\_secrets) | ./modules/secretsmanager | n/a |
| <a name="module_sqs"></a> [sqs](#module\_sqs) | ./modules/sqs | n/a |
| <a name="module_velero"></a> [velero](#module\_velero) | ./modules/velero | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [random_password.this](https://registry.terraform.io/providers/hashicorp/random/3.9.0/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_dynamodb_table_name"></a> [aws\_dynamodb\_table\_name](#input\_aws\_dynamodb\_table\_name) | Nome da tabela DynamoDB | `string` | n/a | yes |
| <a name="input_aws_eks_cluster_version"></a> [aws\_eks\_cluster\_version](#input\_aws\_eks\_cluster\_version) | n/a | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Região AWS onde a infra é provisionada — usada pelo module.velero (não altera o provider aws, que segue as credenciais ambiente/CLI) | `string` | `"us-east-1"` | no |
| <a name="input_aws_sqs_queue_name"></a> [aws\_sqs\_queue\_name](#input\_aws\_sqs\_queue\_name) | n/a | `string` | n/a | yes |
| <a name="input_aws_vpc"></a> [aws\_vpc](#input\_aws\_vpc) | Configuração de rede AWS | <pre>object({<br/>    name                     = string<br/>    cidr_block               = string<br/>    internet_gateway_name    = string<br/>    nat_gateway_name         = string<br/>    public_route_table_name  = string<br/>    private_route_table_name = string<br/>    public_subnets = list(object({<br/>      name                    = string<br/>      cidr_block              = string<br/>      availability_zone       = string<br/>      map_public_ip_on_launch = bool<br/>    }))<br/>    private_subnets = list(object({<br/>      name                    = string<br/>      cidr_block              = string<br/>      availability_zone       = string<br/>      map_public_ip_on_launch = bool<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_backup_notification_email"></a> [backup\_notification\_email](#input\_backup\_notification\_email) | E-mail para notificação de falha/sucesso de backup e restore. Vazio desativa a inscrição SNS | `string` | `""` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Dias de retenção dos recovery points no vault | `number` | `7` | no |
| <a name="input_backup_schedule_cron"></a> [backup\_schedule\_cron](#input\_backup\_schedule\_cron) | Expressão cron (formato AWS Backup) de agendamento do backup | `string` | `"cron(0 6 * * ? *)"` | no |
| <a name="input_backup_vault_name"></a> [backup\_vault\_name](#input\_backup\_vault\_name) | Nome do AWS Backup vault | `string` | `"fiap-tc-f5-backup-vault"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Ambiente da infra provisionada — vira a tag Environment em todos os recursos | `string` | `"Development"` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | Repositório GitHub (owner/repo) que recebe o repository\_dispatch do incident-bridge | `string` | `"nascied/fiap-tech-challenge-fase-5-infra"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | Token do GitHub com permissão de repository\_dispatch no repo acima (não versionar valor real) | `string` | n/a | yes |
| <a name="input_pagerduty_webhook_secret"></a> [pagerduty\_webhook\_secret](#input\_pagerduty\_webhook\_secret) | Secret de verificação de assinatura da subscription de webhook V3 do PagerDuty (não versionar valor real) | `string` | n/a | yes |
| <a name="input_rds"></a> [rds](#input\_rds) | n/a | <pre>object({<br/>    rds_properties = list(object({<br/>      name    = string<br/>      db_name = string<br/>      db_user = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_velero_bucket_name"></a> [velero\_bucket\_name](#input\_velero\_bucket\_name) | Nome do bucket S3 (globalmente único) onde o Velero grava os backups do cluster | `string` | `"fiap-tc-f5-velero-backups"` | no |
| <a name="input_velero_chart_version"></a> [velero\_chart\_version](#input\_velero\_chart\_version) | Versão do chart Helm vmware-tanzu/velero | `string` | `"8.1.0"` | no |
| <a name="input_velero_included_namespaces"></a> [velero\_included\_namespaces](#input\_velero\_included\_namespaces) | Namespaces do cluster incluídos no backup agendado padrão do Velero | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_velero_namespace"></a> [velero\_namespace](#input\_velero\_namespace) | Namespace onde o Velero será instalado | `string` | `"velero"` | no |
| <a name="input_velero_schedule_cron"></a> [velero\_schedule\_cron](#input\_velero\_schedule\_cron) | Cron (formato padrão, não AWS) do backup agendado padrão do Velero | `string` | `"0 6 * * *"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_release_name"></a> [argocd\_release\_name](#output\_argocd\_release\_name) | Nome do release Helm do ArgoCD |
| <a name="output_argocd_release_namespace"></a> [argocd\_release\_namespace](#output\_argocd\_release\_namespace) | Namespace onde o ArgoCD foi instalado |
| <a name="output_argocd_release_status"></a> [argocd\_release\_status](#output\_argocd\_release\_status) | Status do release Helm do ArgoCD |
| <a name="output_aws_db_instance_connection_strings"></a> [aws\_db\_instance\_connection\_strings](#output\_aws\_db\_instance\_connection\_strings) | PostgreSQL connection string |
| <a name="output_aws_db_instance_endpoint"></a> [aws\_db\_instance\_endpoint](#output\_aws\_db\_instance\_endpoint) | RDS endpoint |
| <a name="output_aws_db_instance_hostname"></a> [aws\_db\_instance\_hostname](#output\_aws\_db\_instance\_hostname) | RDS hostname |
| <a name="output_aws_db_instance_master_user"></a> [aws\_db\_instance\_master\_user](#output\_aws\_db\_instance\_master\_user) | Master username |
| <a name="output_aws_db_instance_name"></a> [aws\_db\_instance\_name](#output\_aws\_db\_instance\_name) | Database name |
| <a name="output_aws_db_instance_port"></a> [aws\_db\_instance\_port](#output\_aws\_db\_instance\_port) | RDS port |
| <a name="output_aws_dynamodb_table_arn"></a> [aws\_dynamodb\_table\_arn](#output\_aws\_dynamodb\_table\_arn) | ARN da tabela DynamoDB |
| <a name="output_aws_dynamodb_table_id"></a> [aws\_dynamodb\_table\_id](#output\_aws\_dynamodb\_table\_id) | ID da tabela DynamoDB |
| <a name="output_aws_dynamodb_table_name"></a> [aws\_dynamodb\_table\_name](#output\_aws\_dynamodb\_table\_name) | Nome da tabela DynamoDB |
| <a name="output_aws_ecr_repository_arn"></a> [aws\_ecr\_repository\_arn](#output\_aws\_ecr\_repository\_arn) | ARN no registry de imagem |
| <a name="output_aws_ecr_repository_registry_id"></a> [aws\_ecr\_repository\_registry\_id](#output\_aws\_ecr\_repository\_registry\_id) | Id do registry de imagem |
| <a name="output_aws_ecr_repository_repository_url"></a> [aws\_ecr\_repository\_repository\_url](#output\_aws\_ecr\_repository\_repository\_url) | URL do registry de imagem |
| <a name="output_aws_eks_cluster_arn"></a> [aws\_eks\_cluster\_arn](#output\_aws\_eks\_cluster\_arn) | ARN do cluster EKS |
| <a name="output_aws_eks_cluster_certificate_authority_data"></a> [aws\_eks\_cluster\_certificate\_authority\_data](#output\_aws\_eks\_cluster\_certificate\_authority\_data) | Certificado da autoridade certificadora do cluster EKS (base64) |
| <a name="output_aws_eks_cluster_endpoint"></a> [aws\_eks\_cluster\_endpoint](#output\_aws\_eks\_cluster\_endpoint) | Endereço do endpoint do cluster EKS |
| <a name="output_aws_eks_cluster_id"></a> [aws\_eks\_cluster\_id](#output\_aws\_eks\_cluster\_id) | Id do clueste EKS |
| <a name="output_aws_eks_cluster_name"></a> [aws\_eks\_cluster\_name](#output\_aws\_eks\_cluster\_name) | Nome do cluster EKS |
| <a name="output_aws_eks_cluster_platform_version"></a> [aws\_eks\_cluster\_platform\_version](#output\_aws\_eks\_cluster\_platform\_version) | Versão do cluster EKS |
| <a name="output_aws_eks_cluster_security_group_id"></a> [aws\_eks\_cluster\_security\_group\_id](#output\_aws\_eks\_cluster\_security\_group\_id) | Security group do cluster EKS (control plane e node group) |
| <a name="output_backup_plan_id"></a> [backup\_plan\_id](#output\_backup\_plan\_id) | ID do plano de backup |
| <a name="output_backup_sns_topic_arn"></a> [backup\_sns\_topic\_arn](#output\_backup\_sns\_topic\_arn) | ARN do tópico SNS de notificação de jobs de backup/restore |
| <a name="output_backup_vault_arn"></a> [backup\_vault\_arn](#output\_backup\_vault\_arn) | ARN do AWS Backup vault |
| <a name="output_donation_service_secret_name"></a> [donation\_service\_secret\_name](#output\_donation\_service\_secret\_name) | Nome do secret do donation-service no Secrets Manager (objectName do SecretProviderClass) |
| <a name="output_incident_bridge_function_url"></a> [incident\_bridge\_function\_url](#output\_incident\_bridge\_function\_url) | URL pública da Lambda-ponte — configurar como destino da webhook subscription V3 no PagerDuty |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID do internet gateway |
| <a name="output_ngo_service_secret_name"></a> [ngo\_service\_secret\_name](#output\_ngo\_service\_secret\_name) | Nome do secret do ngo-service no Secrets Manager (objectName do SecretProviderClass) |
| <a name="output_private_subnet_arns"></a> [private\_subnet\_arns](#output\_private\_subnet\_arns) | ARN das subnets privadas |
| <a name="output_private_subnet_id"></a> [private\_subnet\_id](#output\_private\_subnet\_id) | Ids das subnets privadas |
| <a name="output_public_subnet_arns"></a> [public\_subnet\_arns](#output\_public\_subnet\_arns) | ARN das subnets publicas |
| <a name="output_public_subnet_id"></a> [public\_subnet\_id](#output\_public\_subnet\_id) | Ids das subnetes publicas |
| <a name="output_sqs_queue_arn"></a> [sqs\_queue\_arn](#output\_sqs\_queue\_arn) | ARN da fila SQS |
| <a name="output_sqs_queue_name"></a> [sqs\_queue\_name](#output\_sqs\_queue\_name) | Nome da fila SQS |
| <a name="output_sqs_queue_url"></a> [sqs\_queue\_url](#output\_sqs\_queue\_url) | URL da fila SQS |
| <a name="output_velero_bucket_name"></a> [velero\_bucket\_name](#output\_velero\_bucket\_name) | Bucket S3 usado pelo Velero para backups do cluster EKS |
| <a name="output_velero_release_status"></a> [velero\_release\_status](#output\_velero\_release\_status) | Status do release Helm do Velero |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID da VPC |
