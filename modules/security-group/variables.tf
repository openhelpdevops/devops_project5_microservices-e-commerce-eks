variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "admin_cidr_blocks" { type = list(string) }
variable "tags" { type = map(string) }
