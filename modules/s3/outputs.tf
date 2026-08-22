output "bucket1_name" { value = aws_s3_bucket.application["bucket1"].bucket }
output "bucket2_name" { value = aws_s3_bucket.application["bucket2"].bucket }
output "bucket_names" { value = [aws_s3_bucket.application["bucket1"].bucket, aws_s3_bucket.application["bucket2"].bucket] }
output "kms_key_arn" { value = aws_kms_key.application_s3.arn }
