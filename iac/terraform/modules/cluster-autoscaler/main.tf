#
# Cluster Autoscaler: escala o Node Group do EKS (aws_eks_node_group, gerido
# pelo module.eks) pra cima/baixo com base em pods Pending por falta de
# recurso — sem isso, o desiredSize do ASG fica fixo pra sempre (o maxSize
# configurado no node group é só um teto, ninguém aciona ele sozinho).
#
resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = false # kube-system já existe sempre, não precisa criar

  # Mesmo padrão do module.velero: sem "replace", uma tentativa de apply
  # falha com "cannot re-use a name that is still in use" se já existir um
  # release "cluster-autoscaler" nesse namespace fora do state do Terraform
  # (ex.: instalado manualmente via `helm install` antes de existir este
  # módulo — foi exatamente o que aconteceu aqui). cleanup_on_fail evita
  # reacumular histórico de release se uma tentativa futura falhar.
  replace         = true
  cleanup_on_fail = true

  timeout = 300

  values = [
    yamlencode({
      # Descobre o Auto Scaling Group sozinho pelas tags que o EKS já aplica
      # automaticamente ao node group na criação (k8s.io/cluster-autoscaler/
      # enabled=true e k8s.io/cluster-autoscaler/<cluster>=owned) — confirmado
      # que essas tags já existem no ASG sem precisar de nada extra aqui.
      autoDiscovery = {
        clusterName = var.cluster_name
      }

      awsRegion = var.aws_region

      # Conta AWS Academy: sem IAM role própria (IRSA/Pod Identity — ambos
      # bloqueados nesta conta pros outros add-ons, ver CLAUDE.md). Sem
      # anotação de role na ServiceAccount, o pod cai pra instance profile do
      # node (LabRole via IMDS) — mesmo padrão do module.velero. Validado de
      # verdade contra a conta real (pod com credenciais AWS CLI usando a
      # LabRole via IMDS) que ela já tem as 4 permissões necessárias
      # (autoscaling:DescribeAutoScalingGroups/SetDesiredCapacity/DescribeTags,
      # ec2:DescribeLaunchTemplateVersions) — sem bloqueio, diferente do CSI
      # Driver.

      # scaleDownEnabled=true (default do chart) — decisão explícita do
      # usuário de deixar o cluster reduzir sozinho quando a utilização
      # cair (prioridade FinOps sobre manter sempre os nodes distribuídos
      # entre AZs). Exposto como variável pra reverter fácil sem editar o
      # módulo, caso essa decisão mude (ex.: perto de gravar a demo/vídeo,
      # quando instabilidade do cluster reduzindo nodes não é desejável).
      extraArgs = {
        scale-down-enabled = var.scale_down_enabled
      }
    })
  ]
}
