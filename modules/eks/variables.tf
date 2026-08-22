variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_role_arn" { type = string }
variable "node_role_arn" { type = string }
variable "bastion_role_arn" {
  type    = string
  default = ""
}
variable "tools_role_arn" {
  type    = string
  default = ""
}
variable "bastion_security_group_id" {
  type    = string
  default = ""
}
variable "tools_security_group_id" {
  type    = string
  default = ""
}
variable "cluster_admin_principal_arns" {
  type    = set(string)
  default = []
}
variable "endpoint_public_access" {
  type    = bool
  default = true
}
variable "endpoint_private_access" {
  type    = bool
  default = true
}
variable "public_access_cidrs" { type = list(string) }
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
variable "node_min_size" { type = number }
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
variable "enable_ebs_csi" {
  type    = bool
  default = true
}
variable "tags" { type = map(string) }
