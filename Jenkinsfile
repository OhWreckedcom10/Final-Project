pipeline {
    agent {
        kubernetes {
            defaultContainer 'python'

            yaml '''
apiVersion: v1
kind: Pod
spec:
  restartPolicy: Never

  containers:
    - name: python
      image: python:3.11-slim
      command:
        - sh
        - -c
      args:
        - cat
      tty: true

    - name: aws
      image: public.ecr.aws/aws-cli/aws-cli:2.27.49
      command:
        - sh
        - -c
      args:
        - cat
      tty: true
      volumeMounts:
        - name: kaniko-config
          mountPath: /kaniko/.docker
        - name: kubeconfig
          mountPath: /home/jenkins/.kube

    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command:
        - sh
        - -c
      args:
        - cat
      tty: true
      volumeMounts:
        - name: kaniko-config
          mountPath: /kaniko/.docker

    - name: trivy
      image: aquasec/trivy:0.61.1
      command:
        - sh
        - -c
      args:
        - cat
      tty: true

    - name: kubectl
      image: bitnami/kubectl:1.31.12
      command:
        - /bin/bash
        - -c
      args:
        - sleep infinity
      tty: true
      volumeMounts:
        - name: kubeconfig
          mountPath: /home/jenkins/.kube

  volumes:
    - name: kaniko-config
      emptyDir: {}

    - name: kubeconfig
      emptyDir: {}
'''
        }
    }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        AWS_REGION        = 'il-central-1'
        AWS_ACCOUNT_ID    = '539896451836'
        ECR_REGISTRY      = '539896451836.dkr.ecr.il-central-1.amazonaws.com'
        ECR_REPOSITORY    = 'final-project'
        EKS_CLUSTER       = 'final-project'

        APP_NAME          = 'final-project'
        DEV_NAMESPACE     = 'dev'
        PROD_NAMESPACE    = 'prod'

        KUBECONFIG        = '/home/jenkins/.kube/config'

        /*
         * Jenkins credential type:
         * Username with password
         *
         * Username = AWS Access Key ID
         * Password = AWS Secret Access Key
         */
        AWS_CREDENTIALS_ID = 'aws-jenkins-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                container('jnlp') {
                    checkout scm

                    script {
                        env.GIT_SHORT_SHA = sh(
                            script: 'git rev-parse --short=8 HEAD',
                            returnStdout: true
                        ).trim()

                        env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_SHORT_SHA}"
                        env.IMAGE_URI = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${env.IMAGE_TAG}"
                    }

                    echo "Git commit: ${env.GIT_SHORT_SHA}"
                    echo "Image: ${env.IMAGE_URI}"
                }
            }
        }

        stage('Test Application') {
            steps {
                container('python') {
                    sh '''
                        set -eu

                        python3 --version

                        python3 -m venv .venv
                        . .venv/bin/activate

                        python -m pip install --upgrade pip
                        pip install -r requirements.txt

                        python -c "
from app import app

client = app.test_client()
response = client.get('/')

print('HTTP status:', response.status_code)
print('Response:', response.data.decode())

assert response.status_code == 200
"
                    '''
                }
            }
        }

        stage('Configure ECR Authentication') {
            steps {
                container('aws') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            aws sts get-caller-identity

                            mkdir -p /kaniko/.docker

                            ECR_PASSWORD="$(aws ecr get-login-password \
                                --region "${AWS_REGION}")"

                            ECR_AUTH="$(printf 'AWS:%s' "${ECR_PASSWORD}" \
                                | base64 \
                                | tr -d '\\n')"

                            cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${ECR_REGISTRY}": {
      "auth": "${ECR_AUTH}"
    }
  }
}
EOF

                            chmod 600 /kaniko/.docker/config.json

                            echo "ECR authentication configured."
                        '''
                    }
                }
            }
        }

        stage('Build and Push Image') {
            steps {
                container('kaniko') {
                    sh '''
                        set -eu

                        /kaniko/executor \
                            --context="${WORKSPACE}" \
                            --dockerfile="${WORKSPACE}/Dockerfile" \
                            --destination="${IMAGE_URI}" \
                            --cache=true \
                            --cache-repo="${ECR_REGISTRY}/${ECR_REPOSITORY}-cache" \
                            --snapshot-mode=redo \
                            --use-new-run
                    '''
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                container('trivy') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            trivy image \
                                --scanners vuln \
                                --severity HIGH,CRITICAL \
                                --ignore-unfixed \
                                --exit-code 1 \
                                --no-progress \
                                "${IMAGE_URI}"
                        '''
                    }
                }
            }
        }

        stage('Configure EKS Access') {
            steps {
                container('aws') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            mkdir -p "$(dirname "${KUBECONFIG}")"

                            CLUSTER_ENDPOINT="$(aws eks describe-cluster \
                                --region "${AWS_REGION}" \
                                --name "${EKS_CLUSTER}" \
                                --query 'cluster.endpoint' \
                                --output text)"

                            CLUSTER_CA="$(aws eks describe-cluster \
                                --region "${AWS_REGION}" \
                                --name "${EKS_CLUSTER}" \
                                --query 'cluster.certificateAuthority.data' \
                                --output text)"

                            EKS_TOKEN="$(aws eks get-token \
                                --region "${AWS_REGION}" \
                                --cluster-name "${EKS_CLUSTER}" \
                                --query 'status.token' \
                                --output text)"

                            cat > "${KUBECONFIG}" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ${EKS_CLUSTER}
  cluster:
    server: ${CLUSTER_ENDPOINT}
    certificate-authority-data: ${CLUSTER_CA}
contexts:
- name: ${EKS_CLUSTER}
  context:
    cluster: ${EKS_CLUSTER}
    user: jenkins
current-context: ${EKS_CLUSTER}
users:
- name: jenkins
  user:
    token: ${EKS_TOKEN}
EOF

                            chmod 600 "${KUBECONFIG}"

                            echo "EKS kubeconfig created."
                        '''
                    }
                }
            }
        }

        stage('Verify EKS Connection') {
            steps {
                container('kubectl') {
                    sh '''
                        set -eu

                        kubectl cluster-info
                        kubectl get nodes
                    '''
                }
            }
        }

        stage('Deploy to Dev') {
            steps {
                container('kubectl') {
                    sh '''
                        set -eu

                        kubectl create namespace "${DEV_NAMESPACE}" \
                            --dry-run=client \
                            -o yaml | kubectl apply -f -

                        sed "s|IMAGE_URI_PLACEHOLDER|${IMAGE_URI}|g" \
                            k8s/dev/deployment.yaml \
                            | kubectl apply \
                                --namespace "${DEV_NAMESPACE}" \
                                -f -

                        kubectl apply \
                            --namespace "${DEV_NAMESPACE}" \
                            -f k8s/dev/service.yaml

                        kubectl rollout status \
                            deployment/"${APP_NAME}" \
                            --namespace "${DEV_NAMESPACE}" \
                            --timeout=300s
                    '''
                }
            }
        }

        stage('Validate Dev') {
            steps {
                container('kubectl') {
                    sh '''
                        set -eu

                        kubectl get pods \
                            --namespace "${DEV_NAMESPACE}" \
                            -o wide

                        kubectl get services \
                            --namespace "${DEV_NAMESPACE}"

                        kubectl run dev-smoke-test \
                            --namespace "${DEV_NAMESPACE}" \
                            --image=curlimages/curl:8.12.1 \
                            --restart=Never \
                            --attach \
                            --rm \
                            --command -- \
                            curl \
                            --fail \
                            --show-error \
                            --silent \
                            --retry 10 \
                            --retry-delay 5 \
                            "http://${APP_NAME}/"
                    '''
                }
            }
        }

        stage('Approve Production') {
            options {
                timeout(time: 15, unit: 'MINUTES')
            }

            steps {
                input(
                    message: "Deploy ${env.IMAGE_URI} to production?",
                    ok: 'Deploy to Production'
                )
            }
        }

        stage('Deploy to Prod') {
            steps {
                container('kubectl') {
                    sh '''
                        set -eu

                        kubectl create namespace "${PROD_NAMESPACE}" \
                            --dry-run=client \
                            -o yaml | kubectl apply -f -

                        sed "s|IMAGE_URI_PLACEHOLDER|${IMAGE_URI}|g" \
                            k8s/prod/deployment.yaml \
                            | kubectl apply \
                                --namespace "${PROD_NAMESPACE}" \
                                -f -

                        kubectl apply \
                            --namespace "${PROD_NAMESPACE}" \
                            -f k8s/prod/service.yaml

                        kubectl rollout status \
                            deployment/"${APP_NAME}" \
                            --namespace "${PROD_NAMESPACE}" \
                            --timeout=300s
                    '''
                }
            }
        }

        stage('Validate Prod') {
            steps {
                container('kubectl') {
                    sh '''
                        set -eu

                        kubectl get pods \
                            --namespace "${PROD_NAMESPACE}" \
                            -o wide

                        kubectl get services \
                            --namespace "${PROD_NAMESPACE}"

                        kubectl run prod-smoke-test \
                            --namespace "${PROD_NAMESPACE}" \
                            --image=curlimages/curl:8.12.1 \
                            --restart=Never \
                            --attach \
                            --rm \
                            --command -- \
                            curl \
                            --fail \
                            --show-error \
                            --silent \
                            --retry 10 \
                            --retry-delay 5 \
                            "http://${APP_NAME}/"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
            echo "Deployed image: ${env.IMAGE_URI}"
        }

        failure {
            echo 'Pipeline failed. Review the failed stage and Kubernetes events.'
        }

        aborted {
            echo 'Pipeline was aborted or production deployment was not approved.'
        }

        cleanup {
            deleteDir()
        }
    }
}