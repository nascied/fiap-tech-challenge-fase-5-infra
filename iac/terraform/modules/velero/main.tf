#
# Velero: backup e restore do cluster EKS (recursos Kubernetes + volumes EBS).
# Complementa o AWS Backup (que cobre RDS e DynamoDB, fora do cluster).
#
resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  timeout = 600

  values = [
    yamlencode({
      initContainers = [
        {
          name  = "velero-plugin-for-aws"
          image = "velero/velero-plugin-for-aws:v1.11.0"
          volumeMounts = [
            {
              mountPath = "/target"
              name      = "plugins"
            }
          ]
        }
      ]

      # Conta AWS Academy: sem IAM role própria (IRSA). As credenciais vêm da
      # instance profile do node (LabRole — a mesma role usada pelo module.eks
      # para o node group), via cadeia padrão de credenciais do SDK AWS (IMDS).
      credentials = {
        useSecret = false
      }

      configuration = {
        backupStorageLocation = [
          {
            name     = "default"
            provider = "aws"
            bucket   = var.bucket_name
            config = {
              region = var.aws_region
            }
          }
        ]
        volumeSnapshotLocation = [
          {
            name     = "default"
            provider = "aws"
            config = {
              region = var.aws_region
            }
          }
        ]
      }

      # Backup agendado padrão — cobre manifests + snapshot de EBS.
      schedules = {
        default = {
          disabled = false
          schedule = var.schedule_cron
          template = {
            ttl                = var.backup_ttl
            includedNamespaces = var.included_namespaces
          }
        }
      }

      snapshotsEnabled = true

      # node-agent (backup a nível de filesystem via restic/kopia): cobre
      # volumes que não são EBS e serve de fallback ao snapshot nativo.
      deployNodeAgent = true
    })
  ]
}
