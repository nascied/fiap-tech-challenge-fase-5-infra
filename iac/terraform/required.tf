terraform {
  required_version = ">= 1.10.0"
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }

    # Usado por module.backup pra criar o bucket S3 do Velero via AWS CLI
    # (aws_s3_bucket nativo não funciona nesta conta — ver comentário em
    # modules/backup/main.tf).
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
