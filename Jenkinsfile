pipeline {
  agent any
  
  tools {
        terraform 'Jenkins-terraform'
  }
    
  environment {
    AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    AWS_DEFAULT_REGION = 'eu-west-1'
  }

  stages {
    stage('Checkout') {
      steps {
         git branch: 'main' , url:'https://github.com/chingari5268/Terrafrom_SFTP_S3_Assignment.git'
      }
    }

    stage('Terraform Init') {
      steps {
        sh 'terraform init'
      }
    }

    stage('Terraform Validate') {
      steps {
        sh 'terraform validate'
      }
    }
	  
    stage('Terraform Plan') {
      steps {
        withCredentials([string(credentialsId: 'SSH_PRIVATE_KEY', variable: 'SSH_KEY')]) {
          sh 'terraform plan -var "ssh_key_file_content=${SSH_KEY}" -out=tfplan'
        }
      }
    }
  }
}
