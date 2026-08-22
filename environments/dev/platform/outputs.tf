output "cluster_name" { value = module.eks.cluster_name }
output "cluster_arn" { value = module.eks.cluster_arn }
output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}
output "cluster_deletion_protection" { value = module.eks.cluster_deletion_protection }
output "node_group_name" { value = module.eks.node_group_name }
output "ecr_repository_names" { value = module.ecr.repository_names }
output "ecr_repository_urls" { value = module.ecr.repository_urls }
output "vpc_cni_irsa_role_arn" { value = module.eks.vpc_cni_irsa_role_arn }
output "ebs_csi_pod_identity_role_arn" { value = module.eks.ebs_csi_pod_identity_role_arn }
output "update_kubeconfig_command" { value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}" }

output "application_bucket1_name" { value = module.application_s3.bucket1_name }
output "application_bucket2_name" { value = module.application_s3.bucket2_name }

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "aws_load_balancer_controller_role_arn" {
  value = module.eks.aws_load_balancer_controller_role_arn
}

output "aws_load_balancer_controller_policy_arn" {
  value = module.eks.aws_load_balancer_controller_policy_arn
}

output "project_name" {
  value = var.project_name
}

output "environment" {
  value = var.environment
}

output "region" {
  value = var.region
}

output "aws_load_balancer_controller_release_name" {
  value = try(helm_release.aws_load_balancer_controller[0].name, null)
}

output "aws_load_balancer_controller_chart_version" {
  value = try(helm_release.aws_load_balancer_controller[0].version, null)
}
