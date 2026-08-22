variable "project_name" {
  type    = string
  default = "openhelp"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "admin_cidr_blocks" {
  description = "Approved administrator IPv4 CIDRs. Never use 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidr_blocks) > 0 && alltrue([for cidr in var.admin_cidr_blocks : cidr != "0.0.0.0/0"])
    error_message = "admin_cidr_blocks must contain at least one restricted CIDR and must not include 0.0.0.0/0."
  }
}

variable "ami_id" {
  type    = string
  default = ""
}

variable "key_name" {
  description = "Optional EC2 key pair name. Leave empty to use SSM Session Manager only."
  type        = string
  default     = ""
}

variable "create_bastion" {
  type    = bool
  default = true
}

variable "create_tools_host" {
  type    = bool
  default = true
}

variable "bastion_instance_type" {
  type = string
}

variable "tools_instance_type" {
  type = string
}

variable "termination_protection" {
  description = "Keep false for one-step Terraform destroy."
  type        = bool
  default     = false
}

variable "detailed_monitoring" {
  type    = bool
  default = true
}

variable "bastion_root_volume_size" {
  type    = number
  default = 30
}

variable "tools_root_volume_size" {
  type    = number
  default = 100
}
