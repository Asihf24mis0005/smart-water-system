pipeline {
    agent any
    environment {
        // Change from your email address to your exact Docker Hub username handle
        DOCKER_HUB_ID = 'asihf' 
        APP_NAME      = 'water-system'
        VERSION_TAG   = "${BUILD_NUMBER}"
    }


    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['Production', 'Staging'], description: 'Target Execution Space')
    }
    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }
        
        stage('Parallel Automated Testing') {
            parallel {
                stage('HTML Syntax Integrity') {
                    steps {
                        echo "Validating syntax markup tags..."
                        bat "findstr /C:\"</html>\" index.html"
                    }
                }
                stage('Dockerfile Build Assessment') {
                    steps {
                        echo "Verifying structural parameters..."
                        bat "findstr /C:\"FROM nginx\" Dockerfile"
                    }
                }
            }
        }

        stage('Build & Ship Container Image') {
            when {
                expression { params.DEPLOY_ENV == 'Production' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DB_USER', passwordVariable: 'DB_PASS')]) {
                    bat "docker build -t %DOCKER_HUB_ID%/%APP_NAME%:%VERSION_TAG% ."
                    bat "docker build -t %DOCKER_HUB_ID%/%APP_NAME%:latest ."
                    bat "echo %DB_PASS% | docker login -u %DB_USER% --password-stdin"
                    bat "docker push %DOCKER_HUB_ID%/%APP_NAME%:%VERSION_TAG%"
                    bat "docker push %DOCKER_HUB_ID%/%APP_NAME%:latest"
                }
            }
        }

        stage('Deploy Cluster Manifests') {
            steps {
                script {
                    powershell "(Get-Content deployment.yaml) -replace '${DOCKER_HUB_ID}/${APP_NAME}:latest', '${DOCKER_HUB_ID}/${APP_NAME}:${VERSION_TAG}' | Set-Content deployment.yaml"
                    bat "kubectl apply -f deployment.yaml"
                }
            }
        }

        stage('Verify Rollout Status & Auto-Rollback') {
            steps {
                script {
                    try {
                        bat "kubectl rollout status deployment/water-app-deployment --timeout=45s"
                        echo "Deployment stabilized successfully!"
                    } catch (Exception err) {
                        echo "🚨 CRITICAL FAULT DETECTED: Rollout failed to clear stability check!"
                        echo "Executing automated rollback sequence..."
                        bat "kubectl rollout undo deployment/water-app-deployment"
                        bat "kubectl rollout status deployment/water-app-deployment"
                        error("Deployment halted. Automatically rolled back to the last stable release.")
                    }
                }
            }
        }
    }
    post {
        always {
            // Typo removed completely here
            archiveArtifacts artifacts: 'deployment.yaml', onlyIfSuccessful: false
            cleanWs()
        }
    }
}
