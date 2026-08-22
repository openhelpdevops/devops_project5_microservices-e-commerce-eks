variable "project_name" { type = string }
variable "environment" { type = string }
variable "enable_node_ssm" {
  type    = bool
  default = true
}
variable "tags" { type = map(string) }
