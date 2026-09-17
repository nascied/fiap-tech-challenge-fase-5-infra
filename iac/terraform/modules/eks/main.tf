resource "aws_eks_cluster" "this" {
  name     = "${local.resource_prefix_name}-eks"
  version  = var.aws_eks_cluster_version
  role_arn = data.aws_iam_role.this.arn

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = var.aws_subnet_public_ids
  }

  depends_on = [
    data.aws_iam_role.this
  ]
}

resource "aws_eks_addon" "this" {
  for_each     = toset(local.aws_eks_add_ons)
  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value

  configuration_values = lookup(local.aws_eks_add_ons_configuration_values, each.value, null)

  # Exigido pela API do EKS ao definir configuration_values, mesmo quando não há
  # edição manual prévia nos recursos do add-on.
  resolve_conflicts_on_update = lookup(local.aws_eks_add_ons_configuration_values, each.value, null) != null ? "OVERWRITE" : null

  depends_on = [
    aws_eks_node_group.this
  ]
}

resource "aws_launch_template" "this" {
  name_prefix = "${local.resource_prefix_name}-mng-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Eleva o max-pods do kubelet, já que o valor padrão calculado no bootstrap
  # (tabela estática por tipo de instância) não considera o prefix delegation do CNI.
  user_data = base64encode(<<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: application/node.eks.aws

    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          maxPods: 110

    --BOUNDARY--
  EOT
  )
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.resource_prefix_name}-mng"
  node_role_arn   = data.aws_iam_role.this.arn
  subnet_ids      = var.aws_subnet_private_ids
  instance_types  = ["t3.medium"]
  capacity_type   = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_eks_cluster.this,
    data.aws_iam_role.this
  ]
}

resource "aws_eks_access_entry" "this" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/voclabs"

  type = "STANDARD"
  # user_name = "arn:aws:sts::226226079541:assumed-role/voclabs/{{SessionName}}"
}

resource "aws_eks_access_policy_association" "this" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/voclabs"


  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.this
  ]
}