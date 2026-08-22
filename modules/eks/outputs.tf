output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_arn" { value = aws_eks_cluster.this.arn }
output "cluster_endpoint" {
  value     = aws_eks_cluster.this.endpoint
  sensitive = true
}
output "cluster_security_group_id" { value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id }
output "cluster_deletion_protection" { value = aws_eks_cluster.this.deletion_protection }
output "node_group_name" { value = aws_eks_node_group.default.node_group_name }
output "vpc_cni_irsa_role_arn" { value = aws_iam_role.vpc_cni.arn }
output "ebs_csi_pod_identity_role_arn" { value = try(aws_iam_role.ebs_csi[0].arn, null) }
output "eks_kms_key_arn" { value = aws_kms_key.eks.arn }

output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.this.certificate_authority[0].data
  sensitive = true
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  value = aws_iam_openid_connect_provider.eks.url
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

output "aws_load_balancer_controller_policy_arn" {
  value = aws_iam_policy.aws_load_balancer_controller.arn
}
