# Output the S3 bucket ARN
output "s3_bucket_arn" {
  value = aws_s3_bucket.agency_bucket.arn
}

# Output the S3 bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.agency_bucket.id
}
