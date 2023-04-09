pipeline {
  agent any
  
  tools {
    terraform 'Jenkins-terraform'
  }
    
  environment {
    AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
  }

  stages {
    stage('Checkout') {
      steps {
         git branch: 'main' , url:'https://github.com/chingari5268/Terrafrom_SFTP_S3_Assignment.git'
      }
    }

    stage('Terraform Init') {
      steps {
        sh 'terraform init -reconfigure'
      }
    }

    stage('Terraform Validate') {
      steps {
        sh 'terraform validate'
      }
    }
	  
    stage('Terraform Plan') {
      steps {
        sh 'terraform plan -out=tfplan'
      }
    }
	  
    stage('Apply Infrastructure') {
      steps {
        script {
          def proceed = input(
            message: 'Do you want to apply the changes? (yes/no)',
            parameters: [string(name: 'Proceed', defaultValue: 'no')],
          )
          if (proceed == 'yes') {
            sh 'terraform apply -auto-approve tfplan'
          } else {
            echo 'The changes will not be applied'
          }
        }
      }
    }

    stage('Destroy Infrastructure') {
      steps {
        script {
          def destroy = input(
            message: 'Do you want to destroy the resources? (yes/no)',
            parameters: [string(name: 'Destroy', defaultValue: 'no')],
          )
          if (destroy == 'yes') {
            sh 'terraform destroy -auto-approve'
          } else {
            echo 'The infrastructure will not be destroyed'
          }
        }
      }
    }
  }
}
