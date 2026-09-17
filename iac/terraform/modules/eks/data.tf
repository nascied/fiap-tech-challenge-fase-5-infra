data "aws_caller_identity" "current" {}

data "aws_iam_role" "this" {
  name = "LabRole"
}