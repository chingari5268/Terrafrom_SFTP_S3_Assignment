# Configure the AWS provider
provider "aws" {
  region = "eu-west-1"
}

# Create the S3 bucket for each agency
resource "aws_s3_bucket" "agency_bucket" {
  bucket = "${var.agencies}-bucket"

  tags = {
    Name = "${var.agencies}-bucket"
  }
  force_destroy = true
}

# Set the ACL for each S3 bucket
resource "aws_s3_bucket_acl" "agency_bucket_acl" {
  bucket = aws_s3_bucket.agency_bucket.id

  # Set the ACL to private and restrict file types
  acl = "private"
}

# Add lifecycle policy to move data to glacier after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "agency_bucket_lifecycle" {
  bucket = aws_s3_bucket.agency_bucket.id

  rule {
    id      = "move-to-glacier"
    status  = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    filter {
      prefix = "/"
    }
  }
}


# Enable SSE for each S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "agency_bucket_sse" {
  bucket = aws_s3_bucket.agency_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning for each S3 bucket
resource "aws_s3_bucket_versioning" "agency_bucket_versioning" {
  bucket = aws_s3_bucket.agency_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Output the S3 bucket ARN
output "s3_bucket_arn" {
  value = aws_s3_bucket.agency_bucket.arn
}

# Output the S3 bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.agency_bucket.id
}


# Create the IAM roles and policies for each agency
resource "aws_iam_role" "agency_role" {
  name  = "${var.agencies}-role"
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
  name   = "${var.agencies}-policy"
   policy = jsonencode({
    Version   = "2012-10-17"
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
        Condition = {
          "StringEquals": {
            "s3:x-amz-meta-filetype": [
              "csv",
              "excel",
              "json"
            ]
          }
          "NumericLessThanEquals": {
            "s3:content-length": 52428800 # 50 MB
          }
        },
        Principal = {
          AWS = [
            aws_transfer_user.sftp_user.arn
          ]
        }
      }
    ]
  })
}

# Attach the IAM policy to the IAM role for the agency
resource "aws_iam_role_policy_attachment" "agency_policy_attachment" {
  policy_arn      = aws_iam_policy.agency_policy.arn
  role            = aws_iam_role.agency_role.name
}

# Create the SFTP server and users for each agency
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  endpoint_type          = "PUBLIC"
  tags = {
    Name = "${var.agencies}-sftp-server"
  }
  force_destroy = true
}

# Generate an RSA key pair for each agency user
resource "tls_private_key" "sftp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Upload the public key to the SFTP server for each agency user
resource "aws_transfer_ssh_key" "sftp_ssh_key" {
  server_id = aws_transfer_server.sftp.id
  user_name = "${var.agencies}-user"
  body      = tls_private_key.sftp_key.public_key_openssh
}

# Store the private key securely in AWS Secrets Manager for each agency user
resource "aws_kms_key" "sftp_key_kms" {
  description = "KMS key for ${var.agencies} SFTP private key"
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "sftp_key_secret" {
  name        = "${var.agencies}-sftp-key-secret"
  kms_key_id  = aws_kms_key.sftp_key_kms.arn
}

resource "aws_secretsmanager_secret_version" "sftp_key_secret_version" {
  secret_id   = aws_secretsmanager_secret.sftp_key_secret.id
  secret_string = tls_private_key.sftp_key.private_key_pem
}

# Create an SFTP user for each agency with public key authentication
resource "aws_transfer_user" "sftp_user" {
  server_id       = aws_transfer_server.sftp.id
  user_name       = "${var.agencies}-user"
  home_directory  = "/${var.agencies}-bucket"
  role            =  aws_iam_role.agency_role.arn

  tags = {
    Name = "${var.agencies}-sftp-user"
  }
}

# Configure the CloudWatch metric alarm to monitor the S3 bucket for each agency
resource "aws_cloudwatch_metric_alarm" "missing_data_alarm" {
  alarm_name       = "${var.agencies}-missing-data-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  metric_name      = "NumberOfObjects"
  namespace        = "AWS/S3"
  period           = 300 # for every 5 minutes
  statistic        = "Average"
  threshold        = 1
  alarm_description = "Alert if the number of objects in the S3 bucket for ${var.agencies} is less than expected"
  alarm_actions    = [aws_sns_topic.incident_alerts.arn] # Replace with your SNS topic ARN for email notifications

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
