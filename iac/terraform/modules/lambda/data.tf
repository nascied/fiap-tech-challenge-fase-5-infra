# Conta AWS Academy: não é possível criar roles/policies IAM próprias.
# Reaproveita a mesma LabRole já usada pelo module.eks (data.aws_iam_role.this
# em modules/eks/data.tf) e pelo module.backup como role de execução do Lambda.
data "aws_iam_role" "this" {
  name = "LabRole"
}
