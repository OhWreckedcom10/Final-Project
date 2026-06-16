pipeline {
    agent {
        kubernetes {
            yaml """
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
  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret
"""
        }
    }

    environment {
        DOCKER_IMAGE = "ohwrecked/final-project"
        IMAGE_TAG = "${BUILD_NUMBER}"
        K8S_DEPLOYMENT = "final-project"
        K8S_CONTAINER = "final-project"
        K8S_NAMESPACE = "default"
    }

    stages {
        stage('Clone GitHub Repository') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/OhWreckedcom10/Final-Project.git'
            }
        }

        stage('Build Application') {
            steps {
                echo "Python Flask app - no build step required"
            }
        }

        stage('Build and Push Docker Image') {
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
                sh '''
                kubectl apply -f k8s/deployment.yaml
                kubectl apply -f k8s/service.yaml

                kubectl set image deployment/$K8S_DEPLOYMENT \
                $K8S_CONTAINER=$DOCKER_IMAGE:$IMAGE_TAG \
                -n $K8S_NAMESPACE

                kubectl rollout status deployment/$K8S_DEPLOYMENT -n $K8S_NAMESPACE
                '''
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