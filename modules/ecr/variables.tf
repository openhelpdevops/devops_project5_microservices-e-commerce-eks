variable "project_name" { type = string }
variable "environment" { type = string }
variable "repository_names" { type = set(string) }
variable "force_delete" {
  type    = bool
  default = false
}
variable "untagged_retention_days" {
  type    = number
  default = 30
}
variable "tagged_image_count" {
  type    = number
  default = 100
}
variable "tags" { type = map(string) }
