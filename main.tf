# Configure the AWS provider
provider "aws" {
  region = "eu-west-1"
}

# Define the agency name
variable "agency" {
  type    = string
  default = "agency-a"
}

# Create the SFTP server
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  endpoint_type          = "PUBLIC"
  tags = {
    Name = "sftp-server"
  }
}

# Create the S3 bucket for the agency
resource "aws_s3_bucket" "agency_bucket" {
  bucket = "${var.agency}-bucket"
  tags = {
    Name = "${var.agency}-bucket"
  }
}

# Set the ACL for the S3 bucket
resource "aws_s3_bucket_acl" "agency_bucket_acl" {
  bucket = aws_s3_bucket.agency_bucket.id

  # Set the ACL to private
  # See https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl for more options
  acl = "private"
}

# Create the IAM role for the agency
resource "aws_iam_role" "agency_role" {
  name  = "${var.agency}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# Create the IAM policy for the agency
resource "aws_iam_policy" "agency_policy" {
  name  = "${var.agency}-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.agency_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach the IAM policy to the IAM role for the agency
resource "aws_iam_role_policy_attachment" "agency_policy_attachment" {
  policy_arn      = aws_iam_policy.agency_policy.arn
  role            = aws_iam_role.agency_role.name
}


# Create an SSH key for the SFTP user
resource "aws_transfer_ssh_key" "sftp_user_ssh_key" {
  server_id = aws_transfer_server.sftp.id
  user_name = aws_transfer_user.sftp_user.user_name
  body      = file("/home/ubuntu/key/Authentication/jenkinskey.pem")
}

# Configure the SFTP user with the SSH key
resource "aws_transfer_user" "sftp_user" {
  server_id          = aws_transfer_server.sftp.id
  user_name          = "${var.agency}-user"
  home_directory     = "/${var.agency}-bucket"
  home_directory_type = "LOGICAL"
  role               = aws_iam_role.agency_role.arn
}

# Output the values required to connect the SFTP user to the server
output "agency_sftp_server_id" {
  value = aws_transfer_server.sftp.id
}

output "agency_sftp_server_url" {
  value = aws_transfer_server.sftp.endpoint
}


# Configure the CloudWatch metric alarm to monitor the S3 bucket for each agency
resource "aws_cloudwatch_metric_alarm" "missing_data_alarm" {
  alarm_name      = "${var.agency}-missing-data-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  metric_name     = "NumberOfObjects"
  namespace       = "AWS/S3"
  period          = 300 # for every 5 minutes
  statistic       = "Average"
  threshold       = 1
  alarm_description = "Alert if the number of objects in the S3 bucket for ${var.agency} is less than expected"
  alarm_actions   = [aws_sns_topic.incident_alerts.arn] # Replace with your SNS topic ARN for email notifications

  dimensions = {
    BucketName = aws_s3_bucket.agency_bucket.id
  }
}

# Create SNS topic for incident alerts
resource "aws_sns_topic" "incident_alerts" {
  name = "incident-alerts"
}

# Subscribe the SRE team email address to the SNS topic
resource "aws_sns_topic_subscription" "sre_email_subscription" {
  topic_arn = aws_sns_topic.incident_alerts.arn
  protocol  = "email"
  endpoint  = "chethan7119982@gmail.com"
}
