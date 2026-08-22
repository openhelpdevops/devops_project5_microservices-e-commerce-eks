locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Layer       = "network"
  }
}

module "vpc" {
  source = "../../../modules/vpc"

  project_name                = var.project_name
  environment                 = var.environment
  region                      = var.region
  cluster_name                = local.cluster_name
  vpc_cidr                    = var.vpc_cidr
  public_subnet_cidrs         = var.public_subnet_cidrs
  private_subnet_cidrs        = var.private_subnet_cidrs
  availability_zones          = var.availability_zones
  enable_vpc_endpoints        = var.enable_vpc_endpoints
  enable_vpc_flow_logs        = var.enable_vpc_flow_logs
  vpc_flow_log_retention_days = var.vpc_flow_log_retention_days
  tags                        = local.common_tags
}

check "subnet_shape" {
  assert {
    condition = (
      length(var.public_subnet_cidrs) == 2 &&
      length(var.private_subnet_cidrs) == 2 &&
      length(var.availability_zones) == 2
    )
    error_message = "Enterprise network layout requires exactly 2 public subnets, 2 private subnets, and 2 AZs."
  }
}
