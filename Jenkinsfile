pipeline {
    agent any
    environment {
        DOCKER_HUB_ID = 'yourdockerhubusername' // Change to your real lower-case Docker Hub ID
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
                        // Using Windows findstr instead of Linux grep
                        bat "findstr /C:\"</html>\" index.html"
                    }
                }
                stage('Dockerfile Build Assessment') {
                    steps {
                        echo "Verifying structural parameters..."
                        // Using Windows findstr instead of Linux grep
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
                    // Executing via bat for Windows host runners
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
                    // Using powershell string-replacement instead of sed (sed doesn't exist natively on Windows)
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
            archiveArtifacts artifacts: 'deployment.yaml', honesty: false, onlyIfSuccessful: false
            cleanWs()
        }
    }
}

