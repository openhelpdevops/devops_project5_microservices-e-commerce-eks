resource "aws_kms_key" "ecr" {
  description             = "KMS key for ${var.project_name}-${var.environment} ECR repositories"
  deletion_window_in_days = 30
  enable_key_rotation     = true
tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-ecr-kms", Critical = "true" })
}
resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project_name}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

resource "aws_ecr_repository" "this" {
  for_each             = var.repository_names
  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
tags = merge(var.tags, { Name = each.value, Critical = "true" })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after retention period"
        selection = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = var.untagged_retention_days }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep a bounded number of images in each repository"
        selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.tagged_image_count }
        action = { type = "expire" }
      }
    ]
  })
}
