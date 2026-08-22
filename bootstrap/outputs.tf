output "state_bucket_names" { value = { for k, v in aws_s3_bucket.state : k => v.bucket } }
output "state_kms_key_arns" { value = { for k, v in aws_kms_key.state : k => v.arn } }
