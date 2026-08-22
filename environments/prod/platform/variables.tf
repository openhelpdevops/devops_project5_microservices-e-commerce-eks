variable "project_name" {
  type    = string
  default = "openhelp"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "cluster_version" { type = string }
variable "endpoint_public_access" {
  type    = bool
  default = true
}
variable "endpoint_private_access" {
  type    = bool
  default = true
}
variable "public_access_cidrs" {
  type = list(string)
  validation {
    condition = (
      !var.endpoint_public_access ||
      (
        length(var.public_access_cidrs) > 0 &&
        alltrue([for cidr in var.public_access_cidrs : cidr != "0.0.0.0/0"])
      )
    )
    error_message = "When EKS public endpoint access is enabled, provide restricted CIDRs; 0.0.0.0/0 is not allowed."
  }
}
variable "cluster_deletion_protection" {
  type    = bool
  default = true
}
variable "cluster_log_retention_days" {
  type    = number
  default = 90
}
variable "node_instance_types" { type = list(string) }
variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
variable "node_desired_size" { type = number }
variable "node_min_size" {
  type = number
  validation {
    condition     = var.node_min_size >= 1
    error_message = "node_min_size must be at least 1."
  }
}
variable "node_max_size" { type = number }
variable "node_disk_size" {
  type    = number
  default = 80
}
variable "node_disk_iops" {
  type    = number
  default = 3000
}
variable "node_disk_throughput" {
  type    = number
  default = 125
}
variable "cluster_admin_principal_arns" {
  type    = set(string)
  default = []
}

variable "ecr_repository_names" {
  type = set(string)

  validation {
    condition = (
      length(var.ecr_repository_names) > 0 &&
      alltrue([for name in var.ecr_repository_names : length(trimspace(name)) > 0 && !startswith(name, "/") && !endswith(name, "/")])
    )
    error_message = "ecr_repository_names must contain non-empty ECR repository paths without leading or trailing slashes."
  }
}

variable "ecr_force_delete" {
  type    = bool
  default = false
}
variable "ecr_untagged_retention_days" {
  type    = number
  default = 30
}
variable "ecr_tagged_image_count" {
  type    = number
  default = 100
}

variable "application_bucket_force_destroy" {
  type    = bool
  default = false
}
variable "application_bucket_noncurrent_retention_days" {
  type    = number
  default = 90
}

variable "enable_node_ssm" {

  type = bool

  default = true

}

variable "enable_aws_load_balancer_controller" {
  type    = bool
  default = true
}

variable "aws_load_balancer_controller_chart_version" {
  type    = string
  default = "3.5.0"
}

variable "aws_load_balancer_controller_replica_count" {
  type    = number
  default = 2

  validation {
    condition     = var.aws_load_balancer_controller_replica_count >= 2
    error_message = "AWS Load Balancer Controller requires at least two replicas in this platform baseline."
  }
}

variable "enable_aws_load_balancer_controller_pdb" {
  type    = bool
  default = false
}
