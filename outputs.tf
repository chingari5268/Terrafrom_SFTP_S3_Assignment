# Output the S3 bucket ARN
output "s3_bucket_arn" {
  value = aws_s3_bucket.agency_bucket.arn
}

# Output the S3 bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.agency_bucket.id
}

#Output the iam role ARN
output "agency_iam_role_arn" {
  value = aws_iam_role.agency_role.arn
}

#Output the iam Policy ARN
output "agency_iam_policy_arn" {
  value = aws_iam_policy.agency_policy.arn
}

# Output the values required to connect the SFTP user to the server
output "agency_sftp_server_id" {
  value = aws_transfer_server.sftp.id
}

# output the endpoint URL of the SFTP server for agency
output "agency_sftp_server_url" {
  value = aws_transfer_server.sftp.endpoint
}
