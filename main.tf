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

resource "aws_iam_policy" "agency_policy" {
  name   = "${var.agencies}-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.agency_bucket.arn}/*",
          "${aws_s3_bucket.agency_bucket.arn}"
        ]
      },
      {
        Action   = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.agency_bucket.arn}"
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

# Create an SFTP user for each agency with public key authentication
resource "aws_transfer_user" "sftp_user" {
  server_id       = aws_transfer_server.sftp.id
  user_name       = "${var.agencies}-user"
  home_directory  = "/${aws_s3_bucket.agency_bucket.id}"
  role            = aws_iam_role.agency_role.arn
  depends_on = [
    aws_s3_bucket.agency_bucket
  ]
  # Set the IAM policy for the user to allow file uploads to S3
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3Uploads"
        Effect    = "Allow"
        Action   = [
          "s3:*"
        ]
        Resource  = [
          "${aws_s3_bucket.agency_bucket.arn}/*"
        ]
      }
    ]
  })
  tags = {
    Name = "${var.agencies}-sftp-user"
  }
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

  depends_on = [aws_transfer_user.sftp_user]
  
  lifecycle {
    ignore_changes = [
      body,
    ]
  }
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
