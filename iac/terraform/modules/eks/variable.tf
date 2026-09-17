variable "aws_subnet_public_ids" {
  type = list(string)
}

variable "aws_subnet_private_ids" {
  type = list(string)
}

variable "aws_eks_cluster_version" {
  type = string
}