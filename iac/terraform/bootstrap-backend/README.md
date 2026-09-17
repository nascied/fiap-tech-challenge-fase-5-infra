## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.44.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.bucket](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_s3_bucket_name"></a> [aws\_s3\_bucket\_name](#input\_aws\_s3\_bucket\_name) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_s3_bucket_arn"></a> [aws\_s3\_bucket\_arn](#output\_aws\_s3\_bucket\_arn) | n/a |
| <a name="output_aws_s3_bucket_bucket_domain_name"></a> [aws\_s3\_bucket\_bucket\_domain\_name](#output\_aws\_s3\_bucket\_bucket\_domain\_name) | n/a |
| <a name="output_aws_s3_bucket_id"></a> [aws\_s3\_bucket\_id](#output\_aws\_s3\_bucket\_id) | n/a |
