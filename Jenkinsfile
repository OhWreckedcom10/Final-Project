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

    - name: kubectl
      image: bitnami/kubectl:latest
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
                      --context `pwd` \
                      --dockerfile `pwd`/Dockerfile \
                      --destination $DOCKER_IMAGE:$IMAGE_TAG \
                      --destination $DOCKER_IMAGE:latest
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                container('kubectl') {
                    sh 'kubectl version --client'
                }
            }
        }
    }
}