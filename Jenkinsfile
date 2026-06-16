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
        stage('Build Docker Image for Scan') {
            steps {
                container('kaniko') {
                    sh '''
                    /kaniko/executor \
                      --context `pwd` \
                      --dockerfile `pwd`/Dockerfile \
                      --destination $DOCKER_IMAGE:$IMAGE_TAG \
                      --no-push \
                      --tarPath image.tar
                    '''
                }
            }
        }

        stage('Security Scan with Trivy') {
            steps {
                container('trivy') {
                    sh '''
                    trivy image \
                      --input image.tar \
                      --severity CRITICAL \
                      --exit-code 1 \
                      --no-progress
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                container('kaniko') {
                    sh '''
                    /kaniko/executor \
                      --context `pwd` \
                      --dockerfile `pwd`/Dockerfile \
                      --destination $DOCKER_IMAGE:$IMAGE_TAG \
                      --destination $DOCKER_IMAGE:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh '''
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml

                    kubectl set image deployment/final-project \
                    final-project=$DOCKER_IMAGE:$IMAGE_TAG

                    kubectl rollout status deployment/final-project
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}