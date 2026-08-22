variable "project_name" {
  description = "Project name used for naming and tags."
  type        = string
  default     = "openhelp"
}

variable "environment" {
  description = "Environment name: dev, test, or prod."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "region" {
  description = "AWS Region."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR for the environment VPC."
  type        = string
}

variable "availability_zones" {
  description = "Exactly two AZs for the two-AZ enterprise layout."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Exactly two public subnet CIDRs, one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && length(distinct(var.public_subnet_cidrs)) == 2
    error_message = "public_subnet_cidrs must contain exactly two distinct CIDRs."
  }
}

variable "private_subnet_cidrs" {
  description = "Exactly two private subnet CIDRs, one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && length(distinct(var.private_subnet_cidrs)) == 2
    error_message = "private_subnet_cidrs must contain exactly two distinct CIDRs."
  }
}

variable "enable_vpc_endpoints" {
  description = "Create private VPC endpoints used by EC2/EKS workloads."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "vpc_flow_log_retention_days" {
  description = "CloudWatch retention for VPC Flow Logs."
  type        = number
  default     = 90
}
