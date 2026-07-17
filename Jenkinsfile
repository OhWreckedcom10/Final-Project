pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        AWS_REGION  = 'il-central-1'
        AWS_ACCOUNT = '539896451836'
        EKS_CLUSTER = 'final-project'

        ECR_REGISTRY = "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPOSITORY = 'final-project'
        IMAGE_REPOSITORY = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                script {
                    env.GIT_SHORT_COMMIT = sh(
                        script: 'git rev-parse --short=8 HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_SHORT_COMMIT}"
                    env.IMAGE_URI = "${IMAGE_REPOSITORY}:${IMAGE_TAG}"
                }

                echo "Image: ${IMAGE_URI}"
            }
        }

        stage('Test') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate

                    python -m pip install --upgrade pip

                    if [ -f requirements.txt ]; then
                        pip install -r requirements.txt
                    fi

                    if [ -d tests ]; then
                        python -m pytest -v
                    else
                        python -c "from app import app; print('Application import successful')"
                    fi
                '''
            }
        }

        stage('ECR Login') {
            steps {
                sh '''
                    aws ecr get-login-password \
                      --region "${AWS_REGION}" |
                    docker login \
                      --username AWS \
                      --password-stdin "${ECR_REGISTRY}"
                '''
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    docker build \
                      --pull \
                      --tag "${IMAGE_URI}" \
                      .
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    trivy image \
                      --exit-code 1 \
                      --severity CRITICAL \
                      --ignore-unfixed \
                      "${IMAGE_URI}"
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    docker push "${IMAGE_URI}"
                '''
            }
        }

        stage('Configure EKS') {
            steps {
                sh '''
                    aws eks update-kubeconfig \
                      --region "${AWS_REGION}" \
                      --name "${EKS_CLUSTER}"
                '''
            }
        }

        stage('Deploy to Dev') {
            steps {
                sh '''
                    kubectl apply -f k8s/dev/

                    kubectl set image \
                      deployment/final-project \
                      final-project="${IMAGE_URI}" \
                      --namespace dev

                    kubectl annotate deployment/final-project \
                      kubernetes.io/change-cause="Jenkins ${BUILD_NUMBER}: ${IMAGE_URI}" \
                      --namespace dev \
                      --overwrite

                    kubectl rollout status \
                      deployment/final-project \
                      --namespace dev \
                      --timeout=180s
                '''
            }
        }

        stage('Validate Dev') {
            steps {
                sh '''
                    kubectl get deployment,pods,service \
                      --namespace dev

                    DEV_URL=""

                    for attempt in $(seq 1 30); do
                        DEV_URL=$(kubectl get service final-project \
                          --namespace dev \
                          -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

                        if [ -n "${DEV_URL}" ]; then
                            break
                        fi

                        echo "Waiting for the dev LoadBalancer..."
                        sleep 10
                    done

                    if [ -z "${DEV_URL}" ]; then
                        echo "Dev LoadBalancer hostname was not assigned"
                        exit 1
                    fi

                    echo "Testing http://${DEV_URL}"

                    for attempt in $(seq 1 30); do
                        if curl --fail --silent --show-error \
                          "http://${DEV_URL}/"; then
                            exit 0
                        fi

                        echo "Dev validation attempt ${attempt} failed"
                        sleep 10
                    done

                    echo "Dev application validation failed"
                    exit 1
                '''
            }
        }

        stage('Approve Production') {
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input(
                        message: "Promote ${IMAGE_URI} to production?",
                        ok: 'Deploy to production'
                    )
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sh '''
                    kubectl apply -f k8s/prod/

                    kubectl set image \
                      deployment/final-project \
                      final-project="${IMAGE_URI}" \
                      --namespace prod

                    kubectl annotate deployment/final-project \
                      kubernetes.io/change-cause="Jenkins ${BUILD_NUMBER}: ${IMAGE_URI}" \
                      --namespace prod \
                      --overwrite

                    kubectl rollout status \
                      deployment/final-project \
                      --namespace prod \
                      --timeout=300s
                '''
            }
        }

        stage('Validate Prod') {
            steps {
                sh '''
                    kubectl get deployment,pods,service \
                      --namespace prod

                    PROD_URL=""

                    for attempt in $(seq 1 30); do
                        PROD_URL=$(kubectl get service final-project \
                          --namespace prod \
                          -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

                        if [ -n "${PROD_URL}" ]; then
                            break
                        fi

                        echo "Waiting for the production LoadBalancer..."
                        sleep 10
                    done

                    test -n "${PROD_URL}"

                    for attempt in $(seq 1 30); do
                        if curl --fail --silent --show-error \
                          "http://${PROD_URL}/"; then
                            echo "Production validation succeeded"
                            exit 0
                        fi

                        sleep 10
                    done

                    echo "Production validation failed"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment successful: ${IMAGE_URI}"
        }

        failure {
            echo "Pipeline failed. Check the failed stage and Kubernetes events."
        }

        always {
            sh '''
                docker logout "${ECR_REGISTRY}" || true
                docker image rm "${IMAGE_URI}" || true
            '''
        }
    }
}