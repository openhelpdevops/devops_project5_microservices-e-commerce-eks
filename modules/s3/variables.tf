variable "project_name" { type = string }
variable "environment" { type = string }
variable "force_destroy" {
  type    = bool
  default = false
}
variable "noncurrent_version_retention_days" {
  type    = number
  default = 90
}
variable "tags" {
  type    = map(string)
  default = {}
}
