aws_vpc = {
  name                     = "fiap-tc-f5-vpc"
  cidr_block               = "172.16.0.0/16"
  internet_gateway_name    = "fiap-tc-f5-igw"
  nat_gateway_name         = "fiap-tc-f5-ngw"
  public_route_table_name  = "fiap-tc-f5-public-rt"
  private_route_table_name = "fiap-tc-f5-private-rt"
  public_subnets = [{
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
  }]
  private_subnets = [{
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
  }]
}

rds = {
  rds_properties = [{
    name    = "donation-service"
    db_name = "donation_db"
    db_user = "postgres"
    },
    {
      name    = "ngo-service"
      db_name = "ngo_db"
      db_user = "postgres"
  }]
}

aws_sqs_queue_name      = "solidary-donations"
aws_dynamodb_table_name = "SolidaryTechVolunteers"
aws_eks_cluster_version = "1.35"

aws_region  = "us-east-1"
environment = "Production"

# DRP: AWS Backup (RDS + DynamoDB)
backup_vault_name         = "fiap-tc-f5-backup-vault"
backup_schedule_cron      = "cron(0 6 * * ? *)"
backup_retention_days     = 7
backup_notification_email = "" # defina um e-mail para receber alertas de falha de job

# DRP: Velero (backup/restore do cluster EKS)
# Nome do bucket é globalmente único no S3 — ajuste se já estiver em uso.
velero_namespace           = "velero"
velero_chart_version       = "8.1.0"
velero_bucket_name         = "fiap-tc-f5-velero-backups"
velero_schedule_cron       = "0 6 * * *"
velero_included_namespaces = ["*"]