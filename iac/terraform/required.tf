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

    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }
}
