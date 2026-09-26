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
  # Depois de várias tentativas falhas (ImagePullBackOff/BackoffLimitExceeded
  # enquanto corrigíamos a imagem do kubectl.upgrade-crds), o Helm mantém o
  # histórico do release "velero" mesmo com o pre-install hook falhando —
  # sem "replace", a próxima tentativa é recusada com "cannot re-use a name
  # that is still in use". cleanup_on_fail evita reacumular esse mesmo estado
  # se esta tentativa também falhar.
  replace         = true
  cleanup_on_fail = true

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

      # upgradeCRDs=false: o Job upgrade-crds do chart (que roda kubectl apply
      # nas CRDs) é DESNECESSÁRIO na primeira instalação — o Helm já instala
      # os CRDs sozinho via o diretório nativo `crds/` do chart, antes de
      # qualquer hook. O Job só existiria pra cobrir `helm upgrade` (o
      # mecanismo nativo `crds/` só roda no install). Desligado porque esse
      # Job é estruturalmente quebrado nesta versão do chart, não dá pra só
      # trocar a imagem do kubectl:
      #
      # Causa raiz real (confirmada rodando local, não só suposição): o
      # container principal do Job (imagem `velero/velero:v1.15.0`) é baseada
      # em scratch — o binário /velero é Go 100% estático, a imagem não tem
      # NENHUMA libc instalada (nem musl nem glibc), confirmado com
      # `docker create`+`file` no binário. O Job copia um `sh` de uma imagem
      # externa (`kubectl.image`) pra dentro dessa imagem via initContainer e
      # tenta executá-lo — só que **qualquer** `sh` dinamicamente vinculado
      # (bitnami/kubectl:latest → glibc, docker.io/alpine/k8s → musl) falha
      # com `exec: no such file or directory`, porque o interpretador ELF que
      # ele precisa (`/lib64/ld-linux-x86-64.so.2` ou `/lib/ld-musl-x86_64.so.1`)
      # não existe na imagem scratch. Reproduzido isolado com `docker run`
      # compartilhando volume entre as duas imagens, sem precisar do cluster.
      # A única coisa que funcionaria é um `sh` 100% estático (ex.:
      # `busybox:musl`/`busybox:uclibc`, confirmados estáticos) — mas nenhuma
      # imagem pública conhecida combina isso com `kubectl` no mesmo lugar (o
      # que o Job também precisa copiar), e as tentativas anteriores
      # (rancher/kubectl sem shell nenhum; bitnami:latest com bash dinâmico)
      # já tinham sido descartadas por outros motivos. Rota mais simples e
      # robusta: não depender desse mecanismo frágil pra instalação inicial.
      #
      # Trade-off aceito: numa eventual atualização de `chart_version` no
      # futuro, os CRDs não seriam atualizados automaticamente (o mecanismo
      # nativo `crds/` só age no install) — precisaria de um
      # `kubectl apply -f` manual nos CRDs novos nesse momento, ou resolver
      # esse Job de vez (imagem custom com shell estático + kubectl).
      upgradeCRDs = false

      snapshotsEnabled = true

      # node-agent (backup a nível de filesystem via restic/kopia): cobre
      # volumes que não são EBS e serve de fallback ao snapshot nativo.
      deployNodeAgent = true
    })
  ]
}
