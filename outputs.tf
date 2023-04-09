# Output the Bucket ID of each S3 bucket
output "s3_buckets" {
  value = aws_s3_bucket.agency_bucket.*.id
}

# Output the Bucket name of each S3 bucket
output "s3_bucket_names" {
  value = aws_s3_bucket.agency_bucket.*.bucket
}

# Output the ARN of each IAM role
output "agency_role_arns" {
  value = [
    for i in range(length(var.agencies)) :
    aws_iam_role.agency_role[i].arn
  ]
}

# Output the ARN of each IAM policy
output "agency_policy_arns" {
  value = [
    for i in range(length(var.agencies)) :
    aws_iam_policy.agency_policy[i].arn
  ]
}

# Output the values required to connect the SFTP user to the server
output "agency_sftp_server_id" {
  value = [for i in range(length(var.agencies)):
             aws_transfer_server.sftp[i].id
          ]
}

# Print the endpoint URL of the SFTP server for each agency
output "agency_sftp_server_url" {
  value = [for i in range(length(var.agencies)) :
             aws_transfer_server.sftp[i].endpoint
  ]
}
