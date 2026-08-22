data "terraform_remote_state" "network" {
  backend = "s3"
  config = { bucket = "openhelp-terraform-network-state-5739c46b679a", key = "${var.environment}/network/terraform.tfstate", region = var.region }
}
locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
  common_tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform", Layer = "compute" }
}
module "security_group" {
  source = "../../../modules/security-group"
  project_name = var.project_name
  environment = var.environment
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  admin_cidr_blocks = var.admin_cidr_blocks
  tags = local.common_tags
}
module "iam_compute" {
  source = "../../../modules/iam-compute"
  project_name = var.project_name
  environment = var.environment
  region = var.region
  eks_cluster_name = local.cluster_name
  tags = local.common_tags
}
module "ec2" {
  source = "../../../modules/ec2"

  depends_on = [module.iam_compute, module.security_group]
  project_name = var.project_name
  environment = var.environment
  ami_id = var.ami_id
  bastion_instance_type = var.bastion_instance_type
  tools_instance_type = var.tools_instance_type
  public_subnet_id = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  tools_public_subnet_id = data.terraform_remote_state.network.outputs.public_subnet_ids[1]
  bastion_security_group_id = module.security_group.bastion_security_group_id
  tools_security_group_id = module.security_group.tools_security_group_id
  bastion_instance_profile = module.iam_compute.bastion_instance_profile_name
  tools_instance_profile = module.iam_compute.tools_instance_profile_name
  key_name = var.key_name
  create_bastion = var.create_bastion
  create_tools_host = var.create_tools_host
  termination_protection = var.termination_protection
  detailed_monitoring = var.detailed_monitoring
  bastion_root_volume_size = var.bastion_root_volume_size
  tools_root_volume_size = var.tools_root_volume_size
  tags = local.common_tags
}
check "network_state_environment" {
  assert {
    condition     = data.terraform_remote_state.network.outputs.project_name == var.project_name && data.terraform_remote_state.network.outputs.environment == var.environment && data.terraform_remote_state.network.outputs.region == var.region
    error_message = "Compute is reading the wrong network state."
  }
}
