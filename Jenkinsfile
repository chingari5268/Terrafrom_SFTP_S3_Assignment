pipeline {
  agent any
  
  tools {
    terraform 'Jenkins-terraform'
  }
   
  environment {
    AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    AWS_DEFAULT_REGION = 'us-east-1'
    TF_WORKSPACE = readFile 'variables.tf'
  }
  
  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/chingari5268/Terrafrom_SFTP_S3_Assignment.git'
      }
    }
    
    stage('Terraform Init') {
      steps {
          sh 'terraform init'
        }
    }
	
    stage('Terraform Workspace') {
      steps {
          sh "terraform workspace new ${TF_WORKSPACE}"
      }
    }
	
    stage('Terraform Plan') {
      steps {
          sh 'terraform plan'
        }
    }
  }
}
