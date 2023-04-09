terraform {
  backend "s3" {
    bucket = "sftpterraformstatefile"
    key = "prod/aws_infra"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}