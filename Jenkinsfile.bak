pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command:
        - cat
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker

    - name: trivy
      image: aquasec/trivy:latest
      command:
        - cat
      tty: true

    - name: kubectl
      image: alpine/k8s:1.30.0
      command:
        - cat
      tty: true

  volumes:
    - name: docker-config
      secret:
        secretName: dockerhub-secret
'''
        }
    }

    environment {
        DOCKER_IMAGE = "ohwrecked/final-project"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('kaniko') {
                    sh '''
                    /kaniko/executor \
                      --cache=false \
                      --context $(pwd) \
                      --dockerfile $(pwd)/Dockerfile \
                      --destination $DOCKER_IMAGE:$IMAGE_TAG \
                      --destination $DOCKER_IMAGE:latest
                    '''
                }
            }
        }

        stage('Security Scan with Trivy') {
            steps {
                container('trivy') {
                    sh '''
                    trivy image $DOCKER_IMAGE:$IMAGE_TAG \
                      --scanners vuln \
                      --pkg-types library \
                      --severity CRITICAL \
                      --exit-code 1 \
                      --no-progress
                    '''
                }
            }
        }

        stage('Deploy DEV') {
            steps {
                container('kubectl') {
                    sh '''
                    helm upgrade --install hello-world-dev \
                      helm/hello-world \
                      -f environments/dev/values.yaml \
                      -n dev --create-namespace
                    '''
                }
            }
        }

        stage('Approve Promotion To STAGE') {
            steps {
                input(
                    message: 'DEV deployment completed successfully. Promote to STAGE?',
                    ok: 'Deploy STAGE'
                )
            }
        }

        stage('Deploy STAGE') {
            steps {
                container('kubectl') {
                    sh '''
                    helm upgrade --install hello-world-stage \
                      helm/hello-world \
                      -f environments/stage/values.yaml \
                      -n stage --create-namespace
                    '''
                }
            }
        }

        stage('Approve Promotion To PROD') {
            steps {
                input(
                    message: 'STAGE deployment completed successfully. Promote to PROD?',
                    ok: 'Deploy PROD'
                )
            }
        }

        stage('Deploy PROD') {
            steps {
                container('kubectl') {
                    sh '''
                    helm upgrade --install hello-world-prod \
                      helm/hello-world \
                      -f environments/prod/values.yaml \
                      -n prod --create-namespace
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}