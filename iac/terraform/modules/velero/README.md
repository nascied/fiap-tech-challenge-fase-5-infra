## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 3.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.velero](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Região AWS do bucket S3 e dos snapshots de EBS | `string` | `"us-east-1"` | no |
| <a name="input_backup_ttl"></a> [backup\_ttl](#input\_backup\_ttl) | Tempo de retenção de cada backup agendado (formato Go duration, ex.: 168h = 7 dias) | `string` | `"168h"` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Bucket S3 (module.backup.velero\_bucket\_name) onde o Velero grava os backups do cluster | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Versão do chart Helm vmware-tanzu/velero | `string` | `"8.1.0"` | no |
| <a name="input_included_namespaces"></a> [included\_namespaces](#input\_included\_namespaces) | Namespaces do cluster incluídos no backup agendado padrão | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace onde o Velero será instalado | `string` | `"velero"` | no |
| <a name="input_schedule_cron"></a> [schedule\_cron](#input\_schedule\_cron) | Cron (formato padrão, não AWS) do backup agendado padrão do Velero | `string` | `"0 6 * * *"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_velero_release_name"></a> [velero\_release\_name](#output\_velero\_release\_name) | Nome do release Helm do Velero |
| <a name="output_velero_release_namespace"></a> [velero\_release\_namespace](#output\_velero\_release\_namespace) | Namespace onde o Velero foi instalado |
| <a name="output_velero_release_status"></a> [velero\_release\_status](#output\_velero\_release\_status) | Status do release Helm do Velero |
