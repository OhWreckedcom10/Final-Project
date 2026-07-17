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
        - /bin/sh
        - -c
      args:
        - cat
      tty: true

    - name: tools
      image: alpine/k8s:1.31.10
      command:
        - /bin/sh
        - -c
      args:
        - cat
      tty: true
      volumeMounts:
        - name: kubeconfig
          mountPath: /workspace-kube
        - name: kaniko-config
          mountPath: /kaniko/.docker
        - name: ecr-auth
          mountPath: /ecr-auth

    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command:
        - /busybox/sh
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
        - /bin/sh
        - -c
      args:
        - cat
      tty: true
      volumeMounts:
        - name: ecr-auth
          mountPath: /ecr-auth
        - name: trivy-cache
          mountPath: /root/.cache/trivy

  volumes:
    - name: kubeconfig
      emptyDir: {}

    - name: kaniko-config
      emptyDir: {}

    - name: ecr-auth
      emptyDir: {}

    - name: trivy-cache
      emptyDir: {}
'''
        }
    }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        buildDiscarder(
            logRotator(
                numToKeepStr: '10'
            )
        )
        timeout(
            time: 45,
            unit: 'MINUTES'
        )
    }

    environment {
        AWS_REGION = 'il-central-1'
        AWS_ACCOUNT_ID = '539896451836'

        ECR_REGISTRY = '539896451836.dkr.ecr.il-central-1.amazonaws.com'
        ECR_REPOSITORY = 'final-project'

        EKS_CLUSTER = 'final-project'

        APP_NAME = 'final-project'

        DEV_NAMESPACE = 'dev'
        STAGE_NAMESPACE = 'stage'
        PROD_NAMESPACE = 'prod'

        KUBECONFIG = '/workspace-kube/config'

        AWS_CREDENTIALS_ID = 'aws-jenkins-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                container('jnlp') {
                    retry(3){
                        checkout scm
                    }

                    script {
                        env.GIT_SHORT_SHA = sh(
                            script: 'git rev-parse --short=8 HEAD',
                            returnStdout: true
                        ).trim()

                        env.IMAGE_TAG =
                            "${BUILD_NUMBER}-${env.GIT_SHORT_SHA}"

                        env.IMAGE_URI =
                            "${ECR_REGISTRY}/${ECR_REPOSITORY}:${env.IMAGE_TAG}"
                    }

                    echo "Commit: ${env.GIT_SHORT_SHA}"
                    echo "Image: ${env.IMAGE_URI}"
                }
            }
        }

        stage('Test') {
            steps {
                container('python') {
                    sh '''
                        set -eu

                        echo "Python version:"
                        python3 --version

                        python3 -m venv .venv
                        . .venv/bin/activate

                        python -m pip install --upgrade pip
                        pip install -r app/requirements

                        python - <<'PYTHON_TEST'
from app.app import app

client = app.test_client()
response = client.get("/")

print("Status code:", response.status_code)
print("Response:", response.data.decode())

assert response.status_code == 200
PYTHON_TEST
                    '''
                }
            }
        }

        stage('Verify AWS Access') {
            steps {
                container('tools') {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            aws sts get-caller-identity
                            aws eks describe-cluster \
                                --name "${EKS_CLUSTER}" \
                                --region "${AWS_REGION}" \
                                --query 'cluster.status' \
                                --output text
                        '''
                    }
                }
            }
        }

        stage('Configure ECR Authentication') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            mkdir -p /kaniko/.docker
                            mkdir -p /ecr-auth

                            aws ecr get-login-password \
                                --region "${AWS_REGION}" \
                                > /ecr-auth/password

                            chmod 600 /ecr-auth/password

                            ECR_PASSWORD="$(cat /ecr-auth/password)"

                            ECR_AUTH="$(
                                printf 'AWS:%s' "${ECR_PASSWORD}" |
                                base64 |
                                tr -d '\\n'
                            )"

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
                            --snapshot-mode=redo \
                            --image-download-retry=3 \
                            --push-retry=3

                        echo "Image pushed:"
                        echo "${IMAGE_URI}"
                    '''
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                container('trivy') {
                    sh '''
                        set -eu

                        export TRIVY_USERNAME="AWS"
                        export TRIVY_PASSWORD="$(cat /ecr-auth/password)"

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

        stage('Configure EKS Access') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            mkdir -p "$(dirname "${KUBECONFIG}")"

                            aws eks update-kubeconfig \
                                --name "${EKS_CLUSTER}" \
                                --region "${AWS_REGION}" \
                                --kubeconfig "${KUBECONFIG}"

                            chmod 600 "${KUBECONFIG}"

                            echo "Current Kubernetes context:"
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                config current-context

                            echo "Cloud EKS nodes:"
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                get nodes -o wide
                        '''
                    }
                }
            }
        }

        stage('Deploy DEV') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                create namespace "${DEV_NAMESPACE}" \
                                --dry-run=client \
                                -o yaml |
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                apply -f -

                            sed \
                                "s|IMAGE_URI_PLACEHOLDER|${IMAGE_URI}|g" \
                                k8s/dev/deployment.yaml |
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${DEV_NAMESPACE}" \
                                apply -f -

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${DEV_NAMESPACE}" \
                                apply -f k8s/dev/service.yaml

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${DEV_NAMESPACE}" \
                                rollout status \
                                deployment/"${APP_NAME}" \
                                --timeout=300s
                        '''
                    }
                }
            }
        }

        stage('Validate DEV') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${DEV_NAMESPACE}" \
                                get deployments,pods,services -o wide

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${DEV_NAMESPACE}" \
                                run dev-smoke-test \
                                --image=curlimages/curl:8.12.1 \
                                --restart=Never \
                                --rm \
                                --attach \
                                --command -- \
                                curl \
                                --fail \
                                --silent \
                                --show-error \
                                --retry 10 \
                                --retry-delay 5 \
                                "http://${APP_NAME}/"
                        '''
                    }
                }
            }
        }

        stage('Deploy STAGE') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                create namespace "${STAGE_NAMESPACE}" \
                                --dry-run=client \
                                -o yaml |
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                apply -f -

                            sed \
                                "s|IMAGE_URI_PLACEHOLDER|${IMAGE_URI}|g" \
                                k8s/stage/deployment.yaml |
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${STAGE_NAMESPACE}" \
                                apply -f -

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${STAGE_NAMESPACE}" \
                                apply -f k8s/stage/service.yaml

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${STAGE_NAMESPACE}" \
                                rollout status \
                                deployment/"${APP_NAME}" \
                                --timeout=300s
                        '''
                    }
                }
            }
        }

        stage('Validate STAGE') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${STAGE_NAMESPACE}" \
                                get deployments,pods,services -o wide

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${STAGE_NAMESPACE}" \
                                run stage-smoke-test \
                                --image=curlimages/curl:8.12.1 \
                                --restart=Never \
                                --rm \
                                --attach \
                                --command -- \
                                curl \
                                --fail \
                                --silent \
                                --show-error \
                                --retry 10 \
                                --retry-delay 5 \
                                "http://${APP_NAME}/"
                        '''
                    }
                }
            }
        }

        stage('Approve Production') {
            options {
                timeout(
                    time: 15,
                    unit: 'MINUTES'
                )
            }

            steps {
                input(
                    message: """
STAGE deployment passed.

Deploy image:
${env.IMAGE_URI}

to the production namespace on AWS EKS?
""",
                    ok: 'Deploy to Production'
                )
            }
        }

        stage('Deploy PROD') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                create namespace "${PROD_NAMESPACE}" \
                                --dry-run=client \
                                -o yaml |
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                apply -f -

                            sed \
                                "s|IMAGE_URI_PLACEHOLDER|${IMAGE_URI}|g" \
                                k8s/prod/deployment.yaml |
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${PROD_NAMESPACE}" \
                                apply -f -

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${PROD_NAMESPACE}" \
                                apply -f k8s/prod/service.yaml

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${PROD_NAMESPACE}" \
                                rollout status \
                                deployment/"${APP_NAME}" \
                                --timeout=300s
                        '''
                    }
                }
            }
        }

        stage('Validate PROD') {
            steps {
                container('tools') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${AWS_CREDENTIALS_ID}",
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh '''
                            set -eu

                            export AWS_DEFAULT_REGION="${AWS_REGION}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${PROD_NAMESPACE}" \
                                get deployments,pods,services -o wide

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace "${PROD_NAMESPACE}" \
                                run prod-smoke-test \
                                --image=curlimages/curl:8.12.1 \
                                --restart=Never \
                                --rm \
                                --attach \
                                --command -- \
                                curl \
                                --fail \
                                --silent \
                                --show-error \
                                --retry 10 \
                                --retry-delay 5 \
                                "http://${APP_NAME}/"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
            echo "ECR image: ${env.IMAGE_URI}"
            echo 'Deployed to AWS EKS: DEV, STAGE and PROD.'
        }

        failure {
            echo 'Pipeline failed. Check the failed stage in the console output.'
        }

        aborted {
            echo 'Pipeline was aborted or production deployment was not approved.'
        }

        always {
            echo "Build result: ${currentBuild.currentResult}"
        }
    }
}