variable "project_name" {
  description = "Project name used for tagging."
  type        = string
  default     = "openhelp"
}

variable "region" {
  description = "AWS region for the Terraform state infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "state_noncurrent_version_retention_days" {
  description = "Days to retain previous Terraform state object versions."
  type        = number
  default     = 365
}
