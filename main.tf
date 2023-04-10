# Configure the AWS provider
provider "aws" {
  region = "eu-west-1"
}

# Create the S3 bucket for each agency
resource "aws_s3_bucket" "agency_bucket" {
  count  = length(var.agencies)
  bucket = "${var.agencies[count.index]}-bucket"

  tags = {
    Name = "${var.agencies[count.index]}-bucket"
  }
  force_destroy = true
}

# Set the ACL for each S3 bucket
resource "aws_s3_bucket_acl" "agency_bucket_acl" {
  count  = length(var.agencies)
  bucket = aws_s3_bucket.agency_bucket[count.index].id

  # Set the ACL to private and restrict file types
  acl = "private"
}

# Add lifecycle policy to move data to glacier after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "agency_bucket_lifecycle" {
  count  = length(var.agencies)
  bucket = aws_s3_bucket.agency_bucket[count.index].id

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
  count = length(var.agencies)
  name  = "${var.agencies[count.index]}-role"
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
  count  = length(var.agencies)
  name   = "${var.agencies[count.index]}-policy"
   policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.agency_bucket[count.index].arn}/*",
          "${aws_s3_bucket.agency_bucket[count.index].arn}"
        ]
      }
    ]
  })
}

# Attach the IAM policy to the IAM role for the agency
resource "aws_iam_role_policy_attachment" "agency_policy_attachment" {
  count           = length(var.agencies)
  policy_arn      = aws_iam_policy.agency_policy[count.index].arn
  role            = aws_iam_role.agency_role[count.index].name
}

# Create the SFTP server and users for each agency
resource "aws_transfer_server" "sftp" {
  count                 = length(var.agencies)
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  endpoint_type          = "PUBLIC"
  tags = {
    Name = "${var.agencies[count.index]}-sftp-server"
  }
  force_destroy = true
}

# Create an SFTP user for each agency with public key authentication
resource "aws_transfer_user" "sftp_user" {
  count           = length(var.agencies)
  server_id       = aws_transfer_server.sftp[count.index].id
  user_name       = "${var.agencies[count.index]}-user"
  home_directory  = "/${var.agencies[count.index]}-bucket"
  role            = aws_iam_role.agency_role[count.index].arn
  
  # Set the IAM policy for the user to allow file uploads to S3
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3Uploads"
        Effect    = "Allow"
        Action    = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource  = [
          "${aws_s3_bucket.agency_bucket[count.index].arn}/*"
        ]
      }
    ]
  })
  tags = {
    Name = "${var.agencies[count.index]}-sftp-user"
  }
}

# Generate an RSA key pair for each agency user
resource "tls_private_key" "sftp_key" {
  count = length(var.agencies)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Upload the public key to the SFTP server for each agency user
resource "aws_transfer_ssh_key" "sftp_ssh_key" {
  count     = length(var.agencies)
  server_id = aws_transfer_server.sftp[count.index].id
  user_name = "${var.agencies[count.index]}-user"
  body      = tls_private_key.sftp_key[count.index].public_key_openssh

  depends_on = [aws_transfer_user.sftp_user]
  
  lifecycle {
    ignore_changes = [
      body,
    ]
  }
}

# Store the private key securely in AWS Secrets Manager for each agency user
resource "aws_kms_key" "sftp_key_kms" {
  count      = length(var.agencies)
  description = "KMS key for ${var.agencies[count.index]} SFTP private key"
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "sftp_key_secret" {
  count       = length(var.agencies)
  name        = "${var.agencies[count.index]}-sftp-key-secret"
  kms_key_id  = aws_kms_key.sftp_key_kms[count.index].arn
}

resource "aws_secretsmanager_secret_version" "sftp_key_secret_version" {
  count       = length(var.agencies)
  secret_id   = aws_secretsmanager_secret.sftp_key_secret[count.index].id
  secret_string = tls_private_key.sftp_key[count.index].private_key_pem
}
