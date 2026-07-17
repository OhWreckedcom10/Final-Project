pipeline {
    agent {
        kubernetes {
            defaultContainer 'tools'

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
      persistentVolumeClaim:
        claimName: trivy-cache-pvc
'''
        }
    }

    options {
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
        skipDefaultCheckout(true)
    }

    environment {
        AWS_REGION = 'il-central-1'
        AWS_ACCOUNT_ID = '539896451836'

        EKS_CLUSTER = 'final-project'
        ECR_REPOSITORY = 'final-project'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_REPOSITORY = "${ECR_REGISTRY}/${ECR_REPOSITORY}"

        KUBECONFIG = '/workspace-kube/config'

        AWS_CREDENTIALS_ID = 'aws-jenkins-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                container('tools') {
                    retry(3) {
                        checkout scm
                    }

                    script {
                        env.GIT_COMMIT_SHORT = sh(
                            script: 'git rev-parse --short=8 HEAD',
                            returnStdout: true
                        ).trim()

                        env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
                        env.IMAGE_URI = "${IMAGE_REPOSITORY}:${IMAGE_TAG}"
                    }

                    echo "Commit: ${env.GIT_COMMIT_SHORT}"
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
import sys

sys.path.insert(0, "app")

from app import app

client = app.test_client()
response = client.get("/")

print("Status code:", response.status_code)
print("Response:", response.get_data(as_text=True))

if response.status_code != 200:
    raise SystemExit(
        f"Expected HTTP 200, received {response.status_code}"
    )

if "Hello World" not in response.get_data(as_text=True):
    raise SystemExit(
        "Expected response to contain 'Hello World'"
    )
PYTHON_TEST
                    '''
                }
            }
        }

        stage('Verify AWS Access') {
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

                            echo "AWS identity:"
                            aws sts get-caller-identity

                            echo "EKS cluster status:"
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

        stage('Configure EKS') {
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

                            echo "Current Kubernetes context:"
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                config current-context

                            echo "Cluster nodes:"
                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                get nodes -o wide
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

                            AUTH_VALUE="$(
                                printf 'AWS:%s' "${ECR_PASSWORD}" |
                                base64 |
                                tr -d '\\n'
                            )"

                            cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${ECR_REGISTRY}": {
      "auth": "${AUTH_VALUE}"
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
                            --push-retry=3 \
                            --cache=false

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

                        export TRIVY_USERNAME='AWS'
                        export TRIVY_PASSWORD="$(cat /ecr-auth/password)"

                        trivy image \
                            --timeout 15m \
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
                                create namespace dev \
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
                                --namespace dev \
                                apply -f -

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace dev \
                                apply -f k8s/dev/service.yaml

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace dev \
                                rollout status deployment/final-project \
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
                        script {
                            smokeTest('dev')
                        }
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
                                create namespace stage \
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
                                --namespace stage \
                                apply -f -

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace stage \
                                apply -f k8s/stage/service.yaml

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace stage \
                                rollout status deployment/final-project \
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
                        script {
                            smokeTest('stage')
                        }
                    }
                }
            }
        }

        stage('Approve Production') {
            options {
                timeout(time: 15, unit: 'MINUTES')
            }

            steps {
                input(
                    message: """
STAGE deployment passed.

Deploy image:
${env.IMAGE_URI}

to the production namespace on AWS EKS?
""",
                    ok: 'Deploy to PROD'
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
                                create namespace prod \
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
                                --namespace prod \
                                apply -f -

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace prod \
                                apply -f k8s/prod/service.yaml

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                --namespace prod \
                                rollout status deployment/final-project \
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
                        script {
                            smokeTest('prod')
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Build result: ${currentBuild.currentResult}"
        }

        success {
            echo """
Pipeline completed successfully.

Image:
${env.IMAGE_URI}

DEV, STAGE and PROD passed their smoke tests.
"""
        }

        failure {
            echo """
Pipeline failed.

Check the failed stage and the smoke-test diagnostics in the console output.
"""
        }

        aborted {
            echo 'Pipeline was aborted or production approval timed out.'
        }
    }
}

def smokeTest(String namespace) {
    String smokePod = "${namespace}-smoke-${env.BUILD_NUMBER}"

    sh """
        set -eu

        export AWS_DEFAULT_REGION="${env.AWS_REGION}"

        KUBECTL="kubectl --kubeconfig ${env.KUBECONFIG} --namespace ${namespace}"

        cleanup_smoke_test() {
            echo "Cleaning up smoke-test pod ${smokePod}..."

            \$KUBECTL delete pod "${smokePod}" \\
                --ignore-not-found=true \\
                --wait=false >/dev/null 2>&1 || true
        }

        show_diagnostics() {
            echo "===== Smoke-test pod logs ====="
            \$KUBECTL logs "${smokePod}" || true

            echo "===== Smoke-test pod description ====="
            \$KUBECTL describe pod "${smokePod}" || true

            echo "===== Namespace events ====="
            \$KUBECTL get events \\
                --sort-by='.metadata.creationTimestamp' || true
        }

        trap cleanup_smoke_test EXIT INT TERM

        echo "========================================"
        echo "Validating namespace: ${namespace}"
        echo "Image: ${env.IMAGE_URI}"
        echo "Service: http://final-project/"
        echo "Smoke pod: ${smokePod}"
        echo "========================================"

        \$KUBECTL get deployments,pods,services -o wide

        echo "Checking service endpoints..."

        ENDPOINTS="\$(
            \$KUBECTL get endpoints final-project \\
                -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true
        )"

        if [ -z "\${ENDPOINTS}" ]; then
            echo "Service final-project has no ready endpoints."
            \$KUBECTL describe service final-project || true
            \$KUBECTL get pods --show-labels || true
            exit 1
        fi

        echo "Service endpoints: \${ENDPOINTS}"

        cleanup_smoke_test

        echo "Creating smoke-test pod..."

        \$KUBECTL run "${smokePod}" \\
            --image=curlimages/curl:8.12.1 \\
            --restart=Never \\
            --command -- \\
            curl \\
                --fail \\
                --silent \\
                --show-error \\
                --retry 12 \\
                --retry-all-errors \\
                --retry-delay 5 \\
                --connect-timeout 10 \\
                --max-time 120 \\
                http://final-project/

        echo "Waiting for smoke-test pod to finish..."

        ELAPSED=0
        TIMEOUT_SECONDS=180
        INTERVAL=3

        while [ "\${ELAPSED}" -lt "\${TIMEOUT_SECONDS}" ]; do
            PHASE="\$(
                \$KUBECTL get pod "${smokePod}" \\
                    -o jsonpath='{.status.phase}' 2>/dev/null || true
            )"

            echo "Smoke-test phase: \${PHASE:-Pending}"

            case "\${PHASE}" in
                Succeeded)
                    echo "===== Smoke-test response ====="

                    RESPONSE="\$(
                        \$KUBECTL logs "${smokePod}"
                    )"

                    echo "\${RESPONSE}"

                    echo "\${RESPONSE}" |
                        grep -q 'Hello World' || {
                            echo "Expected response was not returned."
                            show_diagnostics
                            exit 1
                        }

                    echo "Smoke test passed for ${namespace}."
                    exit 0
                    ;;

                Failed)
                    echo "Smoke test failed for ${namespace}."
                    show_diagnostics
                    exit 1
                    ;;
            esac

            sleep "\${INTERVAL}"
            ELAPSED=\$((ELAPSED + INTERVAL))
        done

        echo "Smoke test timed out after \${TIMEOUT_SECONDS} seconds."
        show_diagnostics
        exit 1
    """
}