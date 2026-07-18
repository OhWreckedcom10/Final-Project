def updateHelmValues(String valuesFile) {
    container('yq') {
        sh """
            set -eu
            yq -i '.image.repository = strenv(IMAGE_REPOSITORY)' '${valuesFile}'
            yq -i '.image.tag = strenv(IMAGE_TAG)' '${valuesFile}'
            yq -i '.image.pullPolicy = \"IfNotPresent\"' '${valuesFile}'
            yq '.image' '${valuesFile}'
        """
    }
}

def validateHelmChart(String releaseName, String valuesFile, String renderedFile) {
    container('helm') {
        sh """
            set -eu
            helm lint \"${HELM_CHART}\" -f '${valuesFile}'
            helm template '${releaseName}' \"${HELM_CHART}\" \
                -f '${valuesFile}' > '${renderedFile}'
            grep -q '^kind: Rollout$' '${renderedFile}'
            grep -q \"${IMAGE_TAG}\" '${renderedFile}'
        """
    }
}

def commitGitOpsChange(String valuesFile, String message) {
    container('jnlp') {
        withCredentials([
            usernamePassword(
                credentialsId: "${GITHUB_CREDENTIALS_ID}",
                usernameVariable: 'GIT_USERNAME',
                passwordVariable: 'GIT_TOKEN'
            )
        ]) {
            sh """
                set -eu
                git config user.name 'Jenkins GitOps'
                git config user.email 'jenkins@final-project.local'
                git add '${valuesFile}'

                if git diff --cached --quiet; then
                    echo 'No GitOps values change.'
                    exit 0
                fi

                git commit -m '${message}'

                set +x
                git push \
                    \"https://\${GIT_USERNAME}:\${GIT_TOKEN}@${GIT_REPOSITORY}\" \
                    \"HEAD:${GIT_BRANCH}\"
            """
        }
    }
}

def syncArgoApplication(String applicationName) {
    container('tools') {
        sh """
            set -eu
            argocd --core --namespace argocd \
                app sync '${applicationName}' \
                --prune \
                --timeout 300

            argocd --core --namespace argocd \
                app wait '${applicationName}' \
                --sync \
                --health \
                --timeout 300
        """
    }
}

def waitForRollout(String environmentName, String namespaceName, String rolloutName) {
    container('tools') {
        sh """
            set -eu

            timeout 420 sh -c '
                while true; do
                    IMAGE=\$(kubectl -n "${namespaceName}" \
                        get rollout "${rolloutName}" \
                        -o jsonpath="{.spec.template.spec.containers[0].image}")

                    PHASE=\$(kubectl -n "${namespaceName}" \
                        get rollout "${rolloutName}" \
                        -o jsonpath="{.status.phase}")

                    echo "${environmentName} image=\${IMAGE}, phase=\${PHASE}"

                    if [ "\${PHASE}" = "Healthy" ]; then
                        echo "\${IMAGE}" | grep -q ":${IMAGE_TAG}\$"
                        exit 0
                    fi

                    if [ "\${PHASE}" = "Degraded" ]; then
                        kubectl -n "${namespaceName}" describe rollout "${rolloutName}"
                        exit 1
                    fi

                    sleep 10
                done
            '
        """
    }
}

def smokeTest(String environmentName) {
    container('tools') {
        sh """
            set -eu
            chmod +x scripts/smoke-test.sh
            scripts/smoke-test.sh '${environmentName}'
        """
    }
}

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
      command: ["/bin/sh", "-c"]
      args: ["cat"]
      tty: true

    - name: terraform
      image: hashicorp/terraform:1.15.8
      command: ["/bin/sh", "-c"]
      args: ["cat"]
      tty: true
      env:
        - name: TF_IN_AUTOMATION
          value: "true"
        - name: TF_INPUT
          value: "false"
        - name: TF_PLUGIN_CACHE_DIR
          value: /terraform-cache
      volumeMounts:
        - name: terraform-cache
          mountPath: /terraform-cache

    - name: tools
      image: alpine/k8s:1.31.10
      command: ["/bin/sh", "-c"]
      args: ["cat"]
      tty: true
      volumeMounts:
        - name: kubeconfig
          mountPath: /workspace-kube
        - name: kaniko-config
          mountPath: /kaniko/.docker
        - name: ecr-auth
          mountPath: /ecr-auth
        - name: tools-bin
          mountPath: /custom-tools

    - name: helm
      image: alpine/helm:3.17.3
      command: ["/bin/sh", "-c"]
      args: ["cat"]
      tty: true

    - name: yq
      image: mikefarah/yq:4.45.4
      command: ["/bin/sh", "-c"]
      args: ["cat"]
      tty: true

    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command: ["/busybox/sh", "-c"]
      args: ["cat"]
      tty: true
      volumeMounts:
        - name: kaniko-config
          mountPath: /kaniko/.docker

    - name: trivy
      image: aquasec/trivy:0.61.1
      command: ["/bin/sh", "-c"]
      args: ["cat"]
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
    - name: terraform-cache
      emptyDir: {}
    - name: tools-bin
      emptyDir: {}
'''
        }
    }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 90, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        AWS_REGION = 'il-central-1'
        AWS_DEFAULT_REGION = 'il-central-1'
        AWS_ACCOUNT_ID = '539896451836'

        ECR_REGISTRY = '539896451836.dkr.ecr.il-central-1.amazonaws.com'
        ECR_REPOSITORY = 'final-project'
        EKS_CLUSTER = 'final-project'

        TERRAFORM_DIRECTORY = 'terraform'
        TERRAFORM_PLAN_FILE = 'tfplan'
        TERRAFORM_PLAN_TEXT = 'tfplan.txt'
        TERRAFORM_CHANGES = 'false'

        HELM_CHART = 'helm/hello-world'
        DEV_VALUES_FILE = 'environments/dev/values.yaml'
        STAGE_VALUES_FILE = 'environments/stage/values.yaml'
        PROD_VALUES_FILE = 'environments/prod/values.yaml'

        DEV_NAMESPACE = 'dev'
        STAGE_NAMESPACE = 'stage'
        PROD_NAMESPACE = 'prod'

        DEV_ARGO_APP = 'final-project-dev'
        STAGE_ARGO_APP = 'final-project-stage'
        PROD_ARGO_APP = 'final-project-prod'

        DEV_ROLLOUT = 'final-project-dev'
        STAGE_ROLLOUT = 'final-project-stage'
        PROD_ROLLOUT = 'final-project-prod'

        KUBECONFIG = '/workspace-kube/config'
        ARGOCD_VERSION = 'v3.0.6'
        PATH = "/custom-tools:${env.PATH}"

        // This matches the credential ID currently shown in your Jenkins UI.
        GITHUB_CREDENTIALS_ID = 'github-credetials'
        GIT_REPOSITORY = 'github.com/OhWreckedcom10/Final-Project.git'
        GIT_BRANCH = 'main'
    }

    stages {
        stage('Checkout') {
            steps {
                container('jnlp') {
                    retry(3) {
                        checkout scm
                    }

                    script {
                        env.GIT_SHORT_SHA = sh(
                            script: 'git rev-parse --short=8 HEAD',
                            returnStdout: true
                        ).trim()

                        env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_SHORT_SHA}"
                        env.IMAGE_REPOSITORY = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
                        env.IMAGE_URI = "${env.IMAGE_REPOSITORY}:${env.IMAGE_TAG}"
                    }

                    echo "Commit: ${env.GIT_SHORT_SHA}"
                    echo "Image: ${env.IMAGE_URI}"
                }
            }
        }

        stage('Test Application') {
            steps {
                container('python') {
                    sh '''
                        set -eu
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
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        sh '''
                            set -eu
                            aws sts get-caller-identity
                            aws ecr describe-repositories \
                                --repository-names "${ECR_REPOSITORY}" \
                                --region "${AWS_REGION}" \
                                --query 'repositories[0].repositoryUri' \
                                --output text
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

        stage('Install Argo CD CLI') {
            steps {
                container('tools') {
                    sh '''
                        set -eu
                        ARCH="$(uname -m)"
                        case "${ARCH}" in
                            x86_64|amd64) ARGO_ARCH='amd64' ;;
                            aarch64|arm64) ARGO_ARCH='arm64' ;;
                            *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
                        esac

                        wget -q \
                            -O /custom-tools/argocd \
                            "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARGO_ARCH}"
                        chmod 0755 /custom-tools/argocd
                        argocd version --client
                    '''
                }
            }
        }

        stage('Terraform Format') {
            steps {
                container('terraform') {
                    dir("${TERRAFORM_DIRECTORY}") {
                        sh 'terraform fmt -check -recursive'
                    }
                }
            }
        }

        stage('Terraform Init and Validate') {
            steps {
                container('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        dir("${TERRAFORM_DIRECTORY}") {
                            sh '''
                                set -eu
                                terraform init -input=false -no-color
                                terraform validate -no-color
                            '''
                        }
                    }
                }
            }
        }

        stage('Terraform State Safety Check') {
            steps {
                container('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        dir("${TERRAFORM_DIRECTORY}") {
                            script {
                                int status = sh(
                                    returnStatus: true,
                                    script: 'terraform state list > terraform-state-list.txt 2> terraform-state-error.txt'
                                )

                                String resources = fileExists('terraform-state-list.txt') \
                                    ? readFile('terraform-state-list.txt').trim() \
                                    : ''

                                if (status != 0 || resources == '') {
                                    if (fileExists('terraform-state-error.txt')) {
                                        echo readFile('terraform-state-error.txt')
                                    }
                                    error('Terraform state is unavailable or empty. Apply blocked.')
                                }

                                echo "Terraform-managed resources:\n${resources}"
                            }
                        }
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                container('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        dir("${TERRAFORM_DIRECTORY}") {
                            script {
                                int planCode = sh(
                                    returnStatus: true,
                                    script: '''
                                        terraform plan \
                                            -input=false \
                                            -no-color \
                                            -detailed-exitcode \
                                            -out="${TERRAFORM_PLAN_FILE}"
                                    '''
                                )

                                if (planCode == 0) {
                                    env.TERRAFORM_CHANGES = 'false'
                                } else if (planCode == 2) {
                                    env.TERRAFORM_CHANGES = 'true'
                                } else {
                                    error("Terraform plan failed with exit code ${planCode}")
                                }

                                sh '''
                                    terraform show -no-color "${TERRAFORM_PLAN_FILE}" \
                                        > "${TERRAFORM_PLAN_TEXT}"
                                    cat "${TERRAFORM_PLAN_TEXT}"
                                '''
                            }
                        }
                    }
                }

                archiveArtifacts(
                    artifacts: "${TERRAFORM_DIRECTORY}/${TERRAFORM_PLAN_TEXT}",
                    fingerprint: true,
                    allowEmptyArchive: false
                )
            }
        }

        stage('Terraform Apply') {
            when {
                expression { env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                container('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        dir("${TERRAFORM_DIRECTORY}") {
                            sh '''
                                terraform apply \
                                    -input=false \
                                    -no-color \
                                    -auto-approve \
                                    "${TERRAFORM_PLAN_FILE}"
                            '''
                        }
                    }
                }
            }
        }

        stage('Configure ECR Authentication') {
            steps {
                container('tools') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        sh '''
                            set -eu
                            set +x
                            mkdir -p /kaniko/.docker /ecr-auth
                            aws ecr get-login-password --region "${AWS_REGION}" \
                                > /ecr-auth/password
                            chmod 600 /ecr-auth/password
                            ECR_PASSWORD="$(cat /ecr-auth/password)"
                            ECR_AUTH="$(printf 'AWS:%s' "${ECR_PASSWORD}" | base64 | tr -d '\n')"
                            cat > /kaniko/.docker/config.json <<JSON
{
  "auths": {
    "${ECR_REGISTRY}": {
      "auth": "${ECR_AUTH}"
    }
  }
}
JSON
                            chmod 600 /kaniko/.docker/config.json
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
                    '''
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                container('trivy') {
                    sh '''
                        set -eu
                        set +x
                        export TRIVY_USERNAME='AWS'
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
                        [$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-jenkins-credentials',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        sh '''
                            set -eu
                            mkdir -p "$(dirname "${KUBECONFIG}")"
                            aws eks update-kubeconfig \
                                --name "${EKS_CLUSTER}" \
                                --region "${AWS_REGION}" \
                                --kubeconfig "${KUBECONFIG}"
                            chmod 600 "${KUBECONFIG}"
                            kubectl get nodes -o wide
                            kubectl get applications -n argocd
                            argocd --core --namespace argocd app list
                        '''
                    }
                }
            }
        }

        stage('Deploy DEV through Helm and Argo CD') {
            steps {
                script {
                    updateHelmValues(env.DEV_VALUES_FILE)
                    validateHelmChart(env.DEV_ARGO_APP, env.DEV_VALUES_FILE, 'rendered-dev.yaml')
                    commitGitOpsChange(
                        env.DEV_VALUES_FILE,
                        "Deploy ${env.IMAGE_TAG} to dev [skip ci]"
                    )
                    syncArgoApplication(env.DEV_ARGO_APP)
                    waitForRollout('DEV', env.DEV_NAMESPACE, env.DEV_ROLLOUT)
                    smokeTest('dev')
                }
            }
        }

        stage('Deploy STAGE through Helm and Argo CD') {
            steps {
                script {
                    updateHelmValues(env.STAGE_VALUES_FILE)
                    validateHelmChart(env.STAGE_ARGO_APP, env.STAGE_VALUES_FILE, 'rendered-stage.yaml')
                    commitGitOpsChange(
                        env.STAGE_VALUES_FILE,
                        "Promote ${env.IMAGE_TAG} to stage [skip ci]"
                    )
                    syncArgoApplication(env.STAGE_ARGO_APP)
                    waitForRollout('STAGE', env.STAGE_NAMESPACE, env.STAGE_ROLLOUT)
                    smokeTest('stage')
                }
            }
        }

        stage('Approve Production') {
            options {
                timeout(time: 15, unit: 'MINUTES')
            }
            steps {
                input(
                    message: "STAGE passed. Promote ${env.IMAGE_URI} to production?",
                    ok: 'Promote to Production'
                )
            }
        }

        stage('Deploy PROD through Helm and Argo CD') {
            steps {
                script {
                    updateHelmValues(env.PROD_VALUES_FILE)
                    validateHelmChart(env.PROD_ARGO_APP, env.PROD_VALUES_FILE, 'rendered-prod.yaml')
                    commitGitOpsChange(
                        env.PROD_VALUES_FILE,
                        "Promote ${env.IMAGE_TAG} to prod [skip ci]"
                    )
                    syncArgoApplication(env.PROD_ARGO_APP)
                    waitForRollout('PROD', env.PROD_NAMESPACE, env.PROD_ROLLOUT)
                    smokeTest('prod')
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully. Promoted image: ${env.IMAGE_URI}"
        }
        failure {
            echo 'Pipeline failed. Check the failed stage and console output.'
        }
        aborted {
            echo 'Pipeline was aborted or production promotion was not approved.'
        }
        always {
            archiveArtifacts(
                artifacts: "${TERRAFORM_DIRECTORY}/${TERRAFORM_PLAN_TEXT},rendered-*.yaml",
                fingerprint: true,
                allowEmptyArchive: true
            )
            echo "Build result: ${currentBuild.currentResult}"
        }
    }
}
