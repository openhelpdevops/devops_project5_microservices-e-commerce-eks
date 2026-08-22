data "aws_caller_identity" "current" {}

locals {
  state_layers = {
    network  = "openhelp-terraform-network-state-5739c46b679a"
    compute  = "openhelp-terraform-compute-state-5739c46b679a"
    platform = "openhelp-terraform-platform-state-5739c46b679a"
  }
}

resource "aws_kms_key" "state" {
  for_each                = local.state_layers
  description             = "KMS key for OpenHelp ${each.key} Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = { Name = "openhelp-${each.key}-state-kms", Critical = "true" }
}
resource "aws_kms_alias" "state" {
  for_each      = local.state_layers
  name          = "alias/openhelp-${each.key}-state"
  target_key_id = aws_kms_key.state[each.key].key_id
}
resource "aws_s3_bucket" "state" {
  for_each      = local.state_layers
  bucket        = each.value
  force_destroy = true
  tags = { Name = each.value, Purpose = "${title(each.key)} Terraform remote state for dev test prod", Critical = "true" }
}
resource "aws_s3_bucket_versioning" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state[each.key].arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  for_each                = aws_s3_bucket.state
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id
  rule {
    id     = "retain-state-history"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = var.state_noncurrent_version_retention_days }
  }
}
resource "aws_s3_bucket_policy" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*",
      Resource = [each.value.arn, "${each.value.arn}/*"],
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}
