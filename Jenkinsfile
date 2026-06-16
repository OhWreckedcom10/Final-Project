pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "ohwrecked/final-project"
        IMAGE_TAG = "${BUILD_NUMBER}"
        K8S_DEPLOYMENT = "your-deployment-name"
        K8S_CONTAINER = "your-container-name"
        K8S_NAMESPACE = "default"
    }

    stages {

        stage('Clone GitHub Repository') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/your-username/your-repo.git'
            }
        }

        stage('Build Application') {
            steps {
                sh '''
                echo "Building application..."
                # Example for Node.js
                npm install
                npm run build
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $DOCKER_IMAGE:$IMAGE_TAG .
                '''
            }
        }

        stage('Tag Docker Image') {
            steps {
                sh '''
                docker tag $DOCKER_IMAGE:$IMAGE_TAG $DOCKER_IMAGE:latest
                '''
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh '''
                    echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    docker push $DOCKER_IMAGE:$IMAGE_TAG
                    docker push $DOCKER_IMAGE:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                kubectl set image deployment/$K8S_DEPLOYMENT \
                $K8S_CONTAINER=$DOCKER_IMAGE:$IMAGE_TAG \
                -n $K8S_NAMESPACE

                kubectl rollout status deployment/$K8S_DEPLOYMENT -n $K8S_NAMESPACE
                '''
            }
        }
    }
}