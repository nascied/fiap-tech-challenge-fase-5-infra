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

      # O Job upgrade-crds do chart usa uma imagem kubectl cuja tag, por padrão,
      # é derivada da versão do cluster (ex.: "1.35") — mas a Bitnami parou de
      # publicar tags versionadas em docker.io/bitnami/kubectl (só existe mais
      # "latest" e tags de digest), então isso sempre dá ImagePullBackOff em
      # clusters com versão recente. Bug real encontrado rodando contra um
      # cluster EKS de verdade (terraform validate/test não pega isso, é
      # comportamento em runtime do próprio chart).
      #
      # "latest" resolveu o ImagePullBackOff mas trocou o problema por outro:
      # é kubectl client v1.37.0 (confirmado rodando a imagem), 2 versões minor
      # à frente do cluster (EKS 1.35) — acima da política de compatibilidade
      # de skew do Kubernetes (cliente deveria ficar em ±1 do servidor). O Job
      # passou a falhar com BackoffLimitExceeded logo depois dessa troca (não
      # confirmado nos logs — o `cleanup_on_fail=true` do release apagou o pod
      # antes de dar tempo de capturar; hipótese mais forte disponível, não
      # 100% confirmada).
      #
      # Tentativa 1: docker.io/rancher/kubectl:v1.35.6 (tag versionada, bate
      # com o cluster) — DESCARTADA: confirmado rodando a imagem que ela não
      # tem /bin/sh (nem find/ls, é minimalista) — o initContainer deste chart
      # roda `command: [/bin/sh]` explicitamente pra copiar sh+kubectl pro
      # container principal, então quebra de um jeito ainda mais direto.
      # Corrigido com docker.io/alpine/k8s:1.35.8 — Alpine de verdade (tem sh
      # via busybox), tag por versão exata batendo com o cluster. Confirmado
      # rodando o comando exato do initContainer (`cp $(which sh) /tmp && cp
      # $(which kubectl) /tmp`) contra essa imagem antes de aplicar.
      kubectl = {
        image = {
          repository = "docker.io/alpine/k8s"
          tag        = "1.35.8"
        }
      }

      snapshotsEnabled = true

      # node-agent (backup a nível de filesystem via restic/kopia): cobre
      # volumes que não são EBS e serve de fallback ao snapshot nativo.
      deployNodeAgent = true
    })
  ]
}
