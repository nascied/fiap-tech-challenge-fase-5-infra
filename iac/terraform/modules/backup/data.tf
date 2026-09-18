# Conta AWS Academy: não é possível criar roles/policies IAM próprias.
# Reaproveita a mesma LabRole já usada pelo module.eks (data.aws_iam_role.this
# em modules/eks/data.tf) como role de serviço do AWS Backup.
data "aws_iam_role" "this" {
  name = "LabRole"
}

# Usado só pra sufixar o nome do bucket do Velero com o account_id (ver
# locals.tf) — evita colisão de nome globalmente único no S3 entre contas
# Academy diferentes.
data "aws_caller_identity" "current" {}
