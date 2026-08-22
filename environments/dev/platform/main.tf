data "terraform_remote_state" "network" {
  backend = "s3"
  config = { bucket = "openhelp-terraform-network-state-5739c46b679a", key = "${var.environment}/network/terraform.tfstate", region = var.region }
}
data "terraform_remote_state" "compute" {
  backend = "s3"
  config = { bucket = "openhelp-terraform-compute-state-5739c46b679a", key = "${var.environment}/compute/terraform.tfstate", region = var.region }
}
locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
  common_tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform", Layer = "platform" }
}
module "iam_eks" {
  source = "../../../modules/iam-eks"
  project_name = var.project_name
  environment = var.environment
  enable_node_ssm = var.enable_node_ssm
  tags = local.common_tags
}
module "application_s3" {
  source = "../../../modules/s3"
  project_name = var.project_name
  environment = var.environment
  force_destroy = var.application_bucket_force_destroy
  noncurrent_version_retention_days = var.application_bucket_noncurrent_retention_days
  tags = local.common_tags
}
module "ecr" {
  source = "../../../modules/ecr"
  project_name = var.project_name
  environment = var.environment
  repository_names = var.ecr_repository_names
  force_delete = var.ecr_force_delete
  untagged_retention_days = var.ecr_untagged_retention_days
  tagged_image_count = var.ecr_tagged_image_count
  tags = local.common_tags
}
module "eks" {
  source = "../../../modules/eks"

  depends_on = [module.iam_eks]
  project_name = var.project_name
  environment = var.environment
  region = var.region
  cluster_name = local.cluster_name
  cluster_version = var.cluster_version
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  cluster_role_arn = module.iam_eks.eks_cluster_role_arn
  node_role_arn = module.iam_eks.eks_node_role_arn
  bastion_role_arn = data.terraform_remote_state.compute.outputs.bastion_role_arn
  tools_role_arn = data.terraform_remote_state.compute.outputs.tools_role_arn
  bastion_security_group_id = data.terraform_remote_state.compute.outputs.bastion_security_group_id
  tools_security_group_id = data.terraform_remote_state.compute.outputs.tools_security_group_id
  cluster_admin_principal_arns = var.cluster_admin_principal_arns
  endpoint_public_access = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  public_access_cidrs = var.public_access_cidrs
  cluster_deletion_protection = var.cluster_deletion_protection
  cluster_log_retention_days = var.cluster_log_retention_days
  node_instance_types = var.node_instance_types
  node_capacity_type = var.node_capacity_type
  node_desired_size = var.node_desired_size
  node_min_size = var.node_min_size
  node_max_size = var.node_max_size
  node_disk_size = var.node_disk_size
  node_disk_iops = var.node_disk_iops
  node_disk_throughput = var.node_disk_throughput
  tags = local.common_tags
}
check "node_scaling" {
  assert {
    condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
    error_message = "Node scaling must satisfy min <= desired <= max."
  }
}
check "network_state_environment" {
  assert {
    condition     = data.terraform_remote_state.network.outputs.project_name == var.project_name && data.terraform_remote_state.network.outputs.environment == var.environment && data.terraform_remote_state.network.outputs.region == var.region
    error_message = "Platform is reading the wrong network state."
  }
}
check "compute_state_environment" {
  assert {
    condition     = data.terraform_remote_state.compute.outputs.project_name == var.project_name && data.terraform_remote_state.compute.outputs.environment == var.environment && data.terraform_remote_state.compute.outputs.region == var.region
    error_message = "Platform is reading the wrong compute state."
  }
}
