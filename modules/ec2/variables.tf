variable "project_name" { type = string }
variable "environment" { type = string }
variable "ami_id" {
  type    = string
  default = ""
}
variable "bastion_instance_type" { type = string }
variable "tools_instance_type" { type = string }
variable "public_subnet_id" { type = string }
variable "tools_public_subnet_id" { type = string }
variable "bastion_security_group_id" { type = string }
variable "tools_security_group_id" { type = string }
variable "bastion_instance_profile" { type = string }
variable "tools_instance_profile" { type = string }
variable "key_name" {
  type    = string
  default = ""
}
variable "create_bastion" {
  type    = bool
  default = true
}
variable "create_tools_host" {
  type    = bool
  default = true
}
variable "termination_protection" {
  type    = bool
  default = true
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
variable "tags" { type = map(string) }
