data "aws_caller_identity" "current" {}

locals {
  bucket_names = {
    bucket1 = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-app-bucket1"
    bucket2 = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-app-bucket2"
  }
}

resource "aws_kms_key" "application_s3" {
  description             = "KMS key for ${var.project_name}-${var.environment} application S3 buckets"
  deletion_window_in_days = 30
  enable_key_rotation     = true
tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-application-s3-kms", Critical = "true" })
}

resource "aws_kms_alias" "application_s3" {
  name          = "alias/${var.project_name}-${var.environment}-application-s3"
  target_key_id = aws_kms_key.application_s3.key_id
}

resource "aws_s3_bucket" "application" {
  for_each      = local.bucket_names
  bucket        = each.value
  force_destroy = var.force_destroy
tags = merge(var.tags, { Name = each.value, Purpose = "Application/project data", Critical = "true" })
}

resource "aws_s3_bucket_versioning" "application" {
  for_each = aws_s3_bucket.application
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "application" {
  for_each = aws_s3_bucket.application
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.application_s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "application" {
  for_each                = aws_s3_bucket.application
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "application" {
  for_each = aws_s3_bucket.application
  bucket   = each.value.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_lifecycle_configuration" "application" {
  for_each = aws_s3_bucket.application
  bucket   = each.value.id
  rule {
    id     = "expire-old-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "application" {
  for_each = aws_s3_bucket.application
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [each.value.arn, "${each.value.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}
