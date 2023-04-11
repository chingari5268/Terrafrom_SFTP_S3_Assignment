# Output the Bucket ID of each S3 bucket
output "s3_buckets" {
  value = aws_s3_bucket.agency_bucket.id
}

# Output the Bucket name of each S3 bucket
output "s3_bucket_names" {
  value = aws_s3_bucket.agency_bucket.bucket
}

