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
| [helm_release.cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Região AWS do cluster/Auto Scaling Group | `string` | `"us-east-1"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Versão do chart Helm autoscaler/cluster-autoscaler — 9.59.0 tem appVersion 1.35.0, batendo exatamente com a versão do cluster EKS | `string` | `"9.59.0"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Nome do cluster EKS (module.eks.aws\_eks\_cluster\_name) — usado pelo autoDiscovery pra achar o Auto Scaling Group certo | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace onde o Cluster Autoscaler será instalado | `string` | `"kube-system"` | no |
| <a name="input_scale_down_enabled"></a> [scale\_down\_enabled](#input\_scale\_down\_enabled) | Se false, o Cluster Autoscaler só escala pra cima (nunca remove nodes existentes) — útil pra evitar instabilidade antes de uma demo/gravação | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_autoscaler_release_name"></a> [cluster\_autoscaler\_release\_name](#output\_cluster\_autoscaler\_release\_name) | Nome do release Helm do Cluster Autoscaler |
| <a name="output_cluster_autoscaler_release_namespace"></a> [cluster\_autoscaler\_release\_namespace](#output\_cluster\_autoscaler\_release\_namespace) | Namespace onde o Cluster Autoscaler foi instalado |
| <a name="output_cluster_autoscaler_release_status"></a> [cluster\_autoscaler\_release\_status](#output\_cluster\_autoscaler\_release\_status) | Status do release Helm do Cluster Autoscaler |
