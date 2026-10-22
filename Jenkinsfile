pipeline {
    agent any
    environment {
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
                        sh "grep -q '</html>' index.html"
                    }
                }
                stage('Dockerfile Build Assessment') {
                    steps {
                        echo "Verifying structural parameters..."
                        sh "grep -q 'FROM nginx' Dockerfile"
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
                    sh "docker build -t ${DOCKER_HUB_ID}/${APP_NAME}:${VERSION_TAG} ."
                    sh "docker build -t ${DOCKER_HUB_ID}/${APP_NAME}:latest ."
                    sh "echo \$DB_PASS | docker login -u \$DB_USER --password-stdin"
                    sh "docker push ${DOCKER_HUB_ID}/${APP_NAME}:${VERSION_TAG}"
                    sh "docker push ${DOCKER_HUB_ID}/${APP_NAME}:latest"
                }
            }
        }

        stage('Deploy Cluster Manifests') {
            steps {
                script {
                    // Update deployment manifest dynamically with the built image version tag
                    sh "sed -i 's|${DOCKER_HUB_ID}/${APP_NAME}:latest|${DOCKER_HUB_ID}/${APP_NAME}:${VERSION_TAG}|g' deployment.yaml"
                    sh "kubectl apply -f deployment.yaml"
                }
            }
        }

        stage('Verify Rollout Status & Auto-Rollback') {
            steps {
                script {
                    try {
                        // Monitor the pod deployment loop. Timeout catches errors early.
                        sh "kubectl rollout status deployment/water-app-deployment --timeout=45s"
                        echo "Deployment stabilized successfully!"
                    } catch (Exception err) {
                        echo "🚨 CRITICAL FAULT DETECTED: Rollout failed to clear stability check!"
                        echo "Executing automated rollback sequence..."
                        sh "kubectl rollout undo deployment/water-app-deployment"
                        sh "kubectl rollout status deployment/water-app-deployment"
                        error("Deployment halted. Automatically rolled back to the last stable release.")
                    }
                }
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'deployment.yaml', onlyIfSuccessful: false
            cleanWs()
        }
    }
}
