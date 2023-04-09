pipeline {
  agent any
  
  tools {
    terraform 'Jenkins-terraform'
  }
   
  environment {
    AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/chingari5268/Terrafrom_SFTP_S3_Assignment.git'
      }
    }
	
	stage('Workspace') {
	  steps {
        script {
        def workspaceName = "${file('variable.tf')}".replaceAll("[\\n\\t\\r]", "").match(/workspace_name\s+=\s+"(.+?)"/)[1]
        sh "terraform workspace new $workspaceName"
        sh "terraform workspace select $workspaceName"
        } 
      }
    }

	stage('Terraform Plan') {
	  steps {
      sh 'terraform init'
      sh "terraform plan -var-file=variable.tf -out=tfplan"
	  }
	}
  }
}
