# Configure the AWS provider
provider "aws" {
  region = "eu-west-1"
}

# Create the VPC
resource "aws_vpc" "sftp_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "sftp-vpc"
  }
}

# Create a public subnet for the NAT gateway
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.sftp_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# Define the private subnets for the VPC
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.sftp_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "private-subnet"
  }
}

# Create an internet gateway for the VPC
resource "aws_internet_gateway" "sftp_gateway" {
  vpc_id = aws_vpc.sftp_vpc.id
  tags = {
    Name = "sftp-gateway"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.sftp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sftp_gateway.id
  }
  tags = {
    Name = "public-route-table"
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a security group for the SFTP server
resource "aws_security_group" "sftp_security_group" {
  name_prefix = "sftp-security-group-"
  vpc_id      = aws_vpc.sftp_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_region" "current" {
  name = "eu-west-1"
}

# Create a VPC endpoint for the SFTP server
resource "aws_vpc_endpoint" "sftp_vpc_endpoint" {
  count             = length(var.agencies)
  vpc_id            = aws_vpc.sftp_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.transfer.server"
  vpc_endpoint_type = "Interface"

  # Associate the endpoint with the private subnets
  subnet_ids = [
    aws_subnet.private_subnet.id
  ]

  security_group_ids = [
    aws_security_group.sftp_security_group.id
  ]
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
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.agency_bucket[count.index].arn}/*"
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
        }
      }
    ]
  })
}

# Create the SFTP server and associate it with the VPC endpoint
resource "aws_transfer_server" "sftp" {
  count             = length(var.agencies)
  endpoint_type     = "VPC"
  identity_provider = "SERVICE_MANAGED"
  tags = {
    Name        = "sftp-${var.agencies[count.index]}"
  }

  endpoint_details {
    vpc_endpoint_id  = aws_vpc_endpoint.sftp_vpc_endpoint[count.index].id
    security_group_ids = [aws_security_group.sftp_security_group.id]
  }
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
          "s3:PutObject"
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

