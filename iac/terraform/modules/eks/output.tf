output "aws_eks_cluster_id" {
  value = aws_eks_cluster.this.id
}

output "aws_eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "aws_eks_cluster_certificate_authority_data" {
  description = "Certificado da autoridade certificadora do cluster, em base64 (usado por providers kubernetes/helm)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "aws_eks_cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "aws_eks_cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "aws_eks_cluster_platform_version" {
  value = aws_eks_cluster.this.platform_version
}

output "aws_eks_cluster_security_group_id" {
  description = "Security group criado automaticamente pela AWS para o control plane, herdado pelo node group (nenhum dos dois define security_group_ids próprio)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}