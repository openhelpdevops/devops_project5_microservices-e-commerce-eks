output "repository_names" { value = sort([for r in aws_ecr_repository.this : r.name]) }
output "repository_urls" { value = { for name, r in aws_ecr_repository.this : name => r.repository_url } }
output "kms_key_arn" { value = aws_kms_key.ecr.arn }
