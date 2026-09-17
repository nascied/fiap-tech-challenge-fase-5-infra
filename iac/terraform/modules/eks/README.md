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
| [aws_eks_access_entry.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/eks_node_group) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/resources/launch_template) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/data-sources/caller_identity) | data source |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/data-sources/iam_role) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_eks_cluster_version"></a> [aws\_eks\_cluster\_version](#input\_aws\_eks\_cluster\_version) | n/a | `string` | n/a | yes |
| <a name="input_aws_subnet_private_ids"></a> [aws\_subnet\_private\_ids](#input\_aws\_subnet\_private\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_aws_subnet_public_ids"></a> [aws\_subnet\_public\_ids](#input\_aws\_subnet\_public\_ids) | n/a | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_eks_cluster_arn"></a> [aws\_eks\_cluster\_arn](#output\_aws\_eks\_cluster\_arn) | n/a |
| <a name="output_aws_eks_cluster_certificate_authority_data"></a> [aws\_eks\_cluster\_certificate\_authority\_data](#output\_aws\_eks\_cluster\_certificate\_authority\_data) | Certificado da autoridade certificadora do cluster, em base64 (usado por providers kubernetes/helm) |
| <a name="output_aws_eks_cluster_endpoint"></a> [aws\_eks\_cluster\_endpoint](#output\_aws\_eks\_cluster\_endpoint) | n/a |
| <a name="output_aws_eks_cluster_id"></a> [aws\_eks\_cluster\_id](#output\_aws\_eks\_cluster\_id) | n/a |
| <a name="output_aws_eks_cluster_name"></a> [aws\_eks\_cluster\_name](#output\_aws\_eks\_cluster\_name) | n/a |
| <a name="output_aws_eks_cluster_platform_version"></a> [aws\_eks\_cluster\_platform\_version](#output\_aws\_eks\_cluster\_platform\_version) | n/a |
| <a name="output_aws_eks_cluster_security_group_id"></a> [aws\_eks\_cluster\_security\_group\_id](#output\_aws\_eks\_cluster\_security\_group\_id) | Security group criado automaticamente pela AWS para o control plane, herdado pelo node group (nenhum dos dois define security\_group\_ids próprio) |
