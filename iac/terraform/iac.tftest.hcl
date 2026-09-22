mock_provider "aws" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "random" {}

# aws_lambda_function.role valida formato de ARN no client-side; o valor mock
# padrão gerado pelo mock_provider para data.aws_iam_role.this.arn não é um
# ARN válido (outros usos da mesma data source, em modules/eks e
# modules/backup, não têm essa validação estrita e passam sem override).
override_data {
  target = module.incident_bridge.data.aws_iam_role.this
  values = {
    arn = "arn:aws:iam::123456789012:role/LabRole"
  }
}

# Sem isso, "count" em kubernetes_namespace.this (module.k8s_secrets) falha
# com "Invalid count argument": o mock_provider por padrão trata o resultado
# de data.kubernetes_all_namespaces como só conhecido em apply, e count exige
# um valor conhecido em plan. Mesma limitação apareceria de verdade (fora do
# teste) se esse data source dependesse de um provider cuja config só fica
# pronta durante o próprio apply — ver ressalva no CLAUDE.md.
override_data {
  target = module.k8s_secrets.data.kubernetes_all_namespaces.this
  values = {
    namespaces = []
  }
}

variables {
  aws_vpc = {
    name                     = "fiap-tc-f5-vpc"
    cidr_block               = "172.16.0.0/16"
    internet_gateway_name    = "fiap-tc-f5-igw"
    nat_gateway_name         = "fiap-tc-f5-ngw"
    public_route_table_name  = "fiap-tc-f5-public-rt"
    private_route_table_name = "fiap-tc-f5-private-rt"
    public_subnets = [
      {
        name                    = "fiap-tc-f5-public-subnet-us-east-1a"
        cidr_block              = "172.16.1.0/24"
        availability_zone       = "us-east-1a"
        map_public_ip_on_launch = true
      },
      {
        name                    = "fiap-tc-f5-public-subnet-us-east-1b"
        cidr_block              = "172.16.2.0/24"
        availability_zone       = "us-east-1b"
        map_public_ip_on_launch = true
      }
    ]
    private_subnets = [
      {
        name                    = "fiap-tc-f5-private-subnet-us-east-1a"
        cidr_block              = "172.16.10.0/24"
        availability_zone       = "us-east-1a"
        map_public_ip_on_launch = false
      },
      {
        name                    = "fiap-tc-f5-private-subnet-us-east-1b"
        cidr_block              = "172.16.11.0/24"
        availability_zone       = "us-east-1b"
        map_public_ip_on_launch = false
      }
    ]
  }

  rds = {
    rds_properties = [
      {
        name    = "donation-service"
        db_name = "donation_db"
        db_user = "postgres"
      },
      {
        name    = "ngo-service"
        db_name = "ngo_db"
        db_user = "postgres"
      }
    ]
  }

  aws_sqs_queue_name      = "solidary-donations"
  aws_dynamodb_table_name = "SolidaryTechVolunteers"
  aws_eks_cluster_version = "1.35"

  # Mock — module.incident_bridge (ITSM/AIOps self-healing, ver aiops/README.md)
  github_token             = "mock-github-token"
  pagerduty_webhook_secret = "mock-pagerduty-webhook-secret"
}

run "plan_smoke" {
  command = plan

  assert {
    condition     = length(var.aws_vpc.public_subnets) == 2
    error_message = "A VPC deve possuir exatamente 2 subnets públicas."
  }

  assert {
    condition     = length(var.aws_vpc.private_subnets) == 2
    error_message = "A VPC deve possuir exatamente 2 subnets privadas."
  }

  assert {
    condition     = can(regex("^1\\.", var.aws_eks_cluster_version))
    error_message = "A versão do EKS deve iniciar com major 1.x."
  }

  assert {
    condition     = length(var.rds.rds_properties) > 0
    error_message = "A configuração do RDS deve conter ao menos uma instância."
  }
}

run "plan_outputs_shape" {
  command = plan

  assert {
    condition     = length(output.public_subnet_id) == 2
    error_message = "O output de subnets públicas deve retornar 2 IDs."
  }

  assert {
    condition     = length(output.private_subnet_id) == 2
    error_message = "O output de subnets privadas deve retornar 2 IDs."
  }

  assert {
    condition     = length(output.aws_ecr_repository_arn) == 3
    error_message = "O output do ECR deve retornar 3 repositórios (ngo, donation, volunteer)."
  }

  assert {
    condition     = nonsensitive(output.aws_db_instance_name)[0] == "donation_db"
    error_message = "O primeiro nome de banco retornado deve ser donation_db."
  }
}
