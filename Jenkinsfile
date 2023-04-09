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
        withTerraform(variables: [
            [$class: 'FileBinding', variable: 'var_file', terraformFile: 'variable.tf']
          ]) {
            sh "terraform init -var-file=${var_file}"
            sh "terraform workspace new $workspaceName" // create the workspace if it doesn't exist
            sh "terraform workspace select $workspaceName" // select the workspace
          }
      }
    }

  
    stage('Terraform Plan') {
      steps {
        withTerraform(variables: [
            [$class: 'FileBinding', variable: 'var_file', terraformFile: 'variable.tf'],
            [$class: 'StringBinding', variable: 'agency_name', defaultValue: '', description: 'Enter the name of the agency']
          ]) {
            sh "terraform init -var-file=${var_file}"
            sh "terraform workspace select $workspaceName" // select the workspace
            sh "terraform plan -var-file=${var_file} -var 'agencies=${agency_name}' -out=tfplan"
          }
        }
      }
   }
}
