## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_dynamodb_table_name"></a> [aws\_dynamodb\_table\_name](#input\_aws\_dynamodb\_table\_name) | Nome da tabela DynamoDB | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_dynamodb_table_arn"></a> [aws\_dynamodb\_table\_arn](#output\_aws\_dynamodb\_table\_arn) | ARN da tabela |
| <a name="output_aws_dynamodb_table_id"></a> [aws\_dynamodb\_table\_id](#output\_aws\_dynamodb\_table\_id) | ID da tabela |
| <a name="output_aws_dynamodb_table_name"></a> [aws\_dynamodb\_table\_name](#output\_aws\_dynamodb\_table\_name) | Nome da tabela DynamoDB |
