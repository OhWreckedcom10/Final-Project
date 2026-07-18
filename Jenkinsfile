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

    - name: terraform
      image: hashicorp/terraform:1.15.8
      command:
        - /bin/sh
        - -c
      args:
        - cat
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

    - name: helm
      image: alpine/helm:3.17.3
      command:
        - /bin/sh
        - -c
      args:
        - cat
      tty: true

    - name: argocd
      image: quay.io/argoproj/argocd:v3.0.6
      command:
        - /bin/sh
        - -c
      args:
        - cat
      tty: true
      volumeMounts:
        - name: kubeconfig
          mountPath: /workspace-kube

    - name: yq
      image: mikefarah/yq:4.45.4
      command:
        - /bin/sh
        - -c
      args:
        - cat
      tty: true

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

    - name: terraform-cache
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
            time: 90,
            unit: 'MINUTES'
        )
    }

    environment {
        AWS_REGION = 'il-central-1'
        AWS_DEFAULT_REGION = 'il-central-1'
        AWS_ACCOUNT_ID = '539896451836'

        AWS_CREDENTIALS_ID = 'aws-jenkins-credentials'
        GITHUB_CREDENTIALS_ID = 'github-credentials'

        ECR_REGISTRY =
            '539896451836.dkr.ecr.il-central-1.amazonaws.com'

        ECR_REPOSITORY = 'final-project'
        EKS_CLUSTER = 'final-project'
        APP_NAME = 'final-project'

        DEV_NAMESPACE = 'dev'
        STAGE_NAMESPACE = 'stage'
        PROD_NAMESPACE = 'prod'

        DEV_ARGO_APP = 'final-project-dev'
        STAGE_ARGO_APP = 'final-project-stage'
        PROD_ARGO_APP = 'final-project-prod'

        DEV_ROLLOUT = 'final-project-dev'
        STAGE_ROLLOUT = 'final-project-stage'
        PROD_ROLLOUT = 'final-project-prod'

        DEV_VALUES_FILE = 'environments/dev/values.yaml'
        STAGE_VALUES_FILE = 'environments/stage/values.yaml'
        PROD_VALUES_FILE = 'environments/prod/values.yaml'

        HELM_CHART = 'helm/hello-world'

        KUBECONFIG = '/workspace-kube/config'

        TERRAFORM_DIRECTORY = 'terraform'
        TERRAFORM_PLAN_FILE = 'tfplan'
        TERRAFORM_PLAN_TEXT = 'tfplan.txt'

        TERRAFORM_CHANGES = 'false'

        GIT_REPOSITORY =
            'github.com/OhWreckedcom10/Final-Project.git'
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

                        env.IMAGE_TAG =
                            "${BUILD_NUMBER}-${env.GIT_SHORT_SHA}"

                        env.IMAGE_URI =
                            "${ECR_REGISTRY}/${ECR_REPOSITORY}:${env.IMAGE_TAG}"
                    }

                    echo "Commit: ${env.GIT_SHORT_SHA}"
                    echo "Image tag: ${env.IMAGE_TAG}"
                    echo "Image URI: ${env.IMAGE_URI}"
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

                            echo "AWS caller identity:"
                            aws sts get-caller-identity

                            echo "ECR repository:"
                            aws ecr describe-repositories \
                                --repository-names "${ECR_REPOSITORY}" \
                                --region "${AWS_REGION}" \
                                --query \
                                  'repositories[0].repositoryUri' \
                                --output text

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

        stage('Terraform Format') {
            steps {
                container('terraform') {
                    dir("${TERRAFORM_DIRECTORY}") {
                        sh '''
                            set -eu
                            terraform fmt -check -recursive
                        '''
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

                                terraform version

                                terraform init \
                                    -input=false \
                                    -no-color

                                terraform validate \
                                    -no-color
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
                                int stateStatus = sh(
                                    returnStatus: true,
                                    script: '''
                                        terraform state list \
                                            > terraform-state-list.txt \
                                            2> terraform-state-error.txt
                                    '''
                                )

                                String stateResources = ''

                                if (fileExists('terraform-state-list.txt')) {
                                    stateResources =
                                        readFile(
                                            'terraform-state-list.txt'
                                        ).trim()
                                }

                                if (
                                    stateStatus != 0 ||
                                    stateResources == ''
                                ) {
                                    echo '''
Terraform state is unavailable or empty.

Automatic Terraform apply has been blocked.

Configure the remote backend and import the existing
AWS infrastructure before allowing Terraform to apply.
'''

                                    if (
                                        fileExists(
                                            'terraform-state-error.txt'
                                        )
                                    ) {
                                        echo readFile(
                                            'terraform-state-error.txt'
                                        )
                                    }

                                    error(
                                        'Terraform state safety check failed.'
                                    )
                                }

                                echo 'Terraform-managed resources:'
                                echo stateResources
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
                                int terraformExitCode = sh(
                                    returnStatus: true,
                                    script: '''
                                        terraform plan \
                                            -input=false \
                                            -no-color \
                                            -detailed-exitcode \
                                            -out="${TERRAFORM_PLAN_FILE}"
                                    '''
                                )

                                if (terraformExitCode == 0) {
                                    env.TERRAFORM_CHANGES = 'false'
                                    echo 'No Terraform changes detected.'
                                } else if (terraformExitCode == 2) {
                                    env.TERRAFORM_CHANGES = 'true'
                                    echo 'Terraform changes detected.'
                                } else {
                                    error(
                                        "Terraform plan failed with " +
                                        "exit code ${terraformExitCode}."
                                    )
                                }

                                sh '''
                                    terraform show \
                                        -no-color \
                                        "${TERRAFORM_PLAN_FILE}" \
                                        > "${TERRAFORM_PLAN_TEXT}"

                                    echo "===== TERRAFORM PLAN ====="
                                    cat "${TERRAFORM_PLAN_TEXT}"
                                    echo "=========================="
                                '''
                            }
                        }
                    }
                }

                archiveArtifacts(
                    artifacts:
                        "${TERRAFORM_DIRECTORY}/" +
                        "${TERRAFORM_PLAN_TEXT}",
                    fingerprint: true,
                    allowEmptyArchive: false
                )
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    env.TERRAFORM_CHANGES == 'true'
                }
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
                                set -eu

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

                            mkdir -p /kaniko/.docker
                            mkdir -p /ecr-auth

                            aws ecr get-login-password \
                                --region "${AWS_REGION}" \
                                > /ecr-auth/password

                            chmod 600 /ecr-auth/password

                            ECR_PASSWORD="$(
                                cat /ecr-auth/password
                            )"

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

                            chmod 600 \
                                /kaniko/.docker/config.json
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
                            --cache=true \
                            --cache-ttl=24h

                        echo "Pushed image:"
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
                        export TRIVY_PASSWORD="$(
                            cat /ecr-auth/password
                        )"

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

                            mkdir -p "$(
                                dirname "${KUBECONFIG}"
                            )"

                            aws eks update-kubeconfig \
                                --name "${EKS_CLUSTER}" \
                                --region "${AWS_REGION}" \
                                --kubeconfig "${KUBECONFIG}"

                            chmod 600 "${KUBECONFIG}"

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                config current-context

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                get nodes -o wide

                            kubectl \
                                --kubeconfig "${KUBECONFIG}" \
                                get applications \
                                -n argocd
                        '''
                    }
                }
            }
        }

        stage('Update DEV Helm Values') {
            steps {
                container('yq') {
                    sh '''
                        set -eu

                        yq -i \
                          '.image.repository = strenv(ECR_REGISTRY)'\
' + "/" + strenv(ECR_REPOSITORY)' \
                          "${DEV_VALUES_FILE}"

                        yq -i \
                          '.image.tag = strenv(IMAGE_TAG)' \
                          "${DEV_VALUES_FILE}"

                        yq -i \
                          '.image.pullPolicy = "IfNotPresent"' \
                          "${DEV_VALUES_FILE}"

                        echo "Updated DEV values:"
                        yq '.image' "${DEV_VALUES_FILE}"
                    '''
                }
            }
        }

        stage('Validate DEV Helm Chart') {
            steps {
                container('helm') {
                    sh '''
                        set -eu

                        helm lint "${HELM_CHART}" \
                            -f "${DEV_VALUES_FILE}"

                        helm template "${DEV_ARGO_APP}" \
                            "${HELM_CHART}" \
                            -f "${DEV_VALUES_FILE}" \
                            > rendered-dev.yaml

                        grep -q '^kind: Rollout$' \
                            rendered-dev.yaml

                        grep -q "${IMAGE_TAG}" \
                            rendered-dev.yaml
                    '''
                }
            }
        }

        stage('Commit DEV GitOps Change') {
            steps {
                container('jnlp') {
                    withCredentials([
                        usernamePassword(
                            credentialsId:
                                "${GITHUB_CREDENTIALS_ID}",
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_TOKEN'
                        )
                    ]) {
                        sh '''
                            set -eu

                            git config user.name \
                                "Jenkins GitOps"

                            git config user.email \
                                "jenkins@final-project.local"

                            git add "${DEV_VALUES_FILE}"

                            if git diff --cached --quiet; then
                                echo "No DEV values change."
                                exit 0
                            fi

                            git commit \
                                -m "Deploy ${IMAGE_TAG} to dev [skip ci]"

                            set +x

                            git remote set-url origin \
                              "https://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_REPOSITORY}"

                            git push origin HEAD:main

                            set -x
                        '''
                    }
                }
            }
        }

        stage('Argo CD Sync DEV') {
            steps {
                container('argocd') {
                    sh '''
                        set -eu

                        argocd \
                            --core \
                            --kubeconfig "${KUBECONFIG}" \
                            --namespace argocd \
                            app sync "${DEV_ARGO_APP}" \
                            --prune \
                            --timeout 300

                        argocd \
                            --core \
                            --kubeconfig "${KUBECONFIG}" \
                            --namespace argocd \
                            app wait "${DEV_ARGO_APP}" \
                            --sync \
                            --health \
                            --timeout 300
                    '''
                }
            }
        }

        stage('Wait for DEV Rollout') {
            steps {
                container('tools') {
                    sh '''
                        set -eu

                        timeout 360 sh -c '
                            while true; do
                                IMAGE="$(
                                    kubectl \
                                      --kubeconfig \
                                        "${KUBECONFIG}" \
                                      -n "${DEV_NAMESPACE}" \
                                      get rollout \
                                        "${DEV_ROLLOUT}" \
                                      -o jsonpath="{.spec.template.spec.containers[0].image}"
                                )"

                                PHASE="$(
                                    kubectl \
                                      --kubeconfig \
                                        "${KUBECONFIG}" \
                                      -n "${DEV_NAMESPACE}" \
                                      get rollout \
                                        "${DEV_ROLLOUT}" \
                                      -o jsonpath="{.status.phase}"
                                )"

                                echo \
                                  "DEV image=${IMAGE}, phase=${PHASE}"

                                case "${PHASE}" in
                                    Healthy)
                                        echo "${IMAGE}" |
                                            grep -q \
                                            ":${IMAGE_TAG}$"
                                        exit 0
                                        ;;
                                    Degraded)
                                        exit 1
                                        ;;
                                esac

                                sleep 10
                            done
                        '
                    '''
                }
            }
        }

        stage('Validate DEV') {
            steps {
                container('tools') {
                    sh '''
                        set -eu
                        chmod +x scripts/smoke-test.sh
                        scripts/smoke-test.sh dev
                    '''
                }
            }
        }

        stage('Update STAGE Helm Values') {
            steps {
                container('yq') {
                    sh '''
                        set -eu

                        yq -i \
                          '.image.repository = strenv(ECR_REGISTRY)'\
' + "/" + strenv(ECR_REPOSITORY)' \
                          "${STAGE_VALUES_FILE}"

                        yq -i \
                          '.image.tag = strenv(IMAGE_TAG)' \
                          "${STAGE_VALUES_FILE}"

                        yq -i \
                          '.image.pullPolicy = "IfNotPresent"' \
                          "${STAGE_VALUES_FILE}"

                        yq '.image' "${STAGE_VALUES_FILE}"
                    '''
                }
            }
        }

        stage('Validate STAGE Helm Chart') {
            steps {
                container('helm') {
                    sh '''
                        set -eu

                        helm lint "${HELM_CHART}" \
                            -f "${STAGE_VALUES_FILE}"

                        helm template "${STAGE_ARGO_APP}" \
                            "${HELM_CHART}" \
                            -f "${STAGE_VALUES_FILE}" \
                            > rendered-stage.yaml

                        grep -q '^kind: Rollout$' \
                            rendered-stage.yaml

                        grep -q "${IMAGE_TAG}" \
                            rendered-stage.yaml
                    '''
                }
            }
        }

        stage('Commit STAGE GitOps Change') {
            steps {
                container('jnlp') {
                    withCredentials([
                        usernamePassword(
                            credentialsId:
                                "${GITHUB_CREDENTIALS_ID}",
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_TOKEN'
                        )
                    ]) {
                        sh '''
                            set -eu

                            git add "${STAGE_VALUES_FILE}"

                            if git diff --cached --quiet; then
                                echo "No STAGE values change."
                                exit 0
                            fi

                            git commit \
                                -m "Promote ${IMAGE_TAG} to stage [skip ci]"

                            set +x

                            git push origin HEAD:main

                            set -x
                        '''
                    }
                }
            }
        }

        stage('Argo CD Sync STAGE') {
            steps {
                container('argocd') {
                    sh '''
                        set -eu

                        argocd \
                            --core \
                            --kubeconfig "${KUBECONFIG}" \
                            --namespace argocd \
                            app sync "${STAGE_ARGO_APP}" \
                            --prune \
                            --timeout 300

                        argocd \
                            --core \
                            --kubeconfig "${KUBECONFIG}" \
                            --namespace argocd \
                            app wait "${STAGE_ARGO_APP}" \
                            --sync \
                            --health \
                            --timeout 300
                    '''
                }
            }
        }

        stage('Wait for STAGE Rollout') {
            steps {
                container('tools') {
                    sh '''
                        set -eu

                        timeout 360 sh -c '
                            while true; do
                                IMAGE="$(
                                    kubectl \
                                      --kubeconfig \
                                        "${KUBECONFIG}" \
                                      -n "${STAGE_NAMESPACE}" \
                                      get rollout \
                                        "${STAGE_ROLLOUT}" \
                                      -o jsonpath="{.spec.template.spec.containers[0].image}"
                                )"

                                PHASE="$(
                                    kubectl \
                                      --kubeconfig \
                                        "${KUBECONFIG}" \
                                      -n "${STAGE_NAMESPACE}" \
                                      get rollout \
                                        "${STAGE_ROLLOUT}" \
                                      -o jsonpath="{.status.phase}"
                                )"

                                echo \
                                  "STAGE image=${IMAGE}, phase=${PHASE}"

                                case "${PHASE}" in
                                    Healthy)
                                        echo "${IMAGE}" |
                                            grep -q \
                                            ":${IMAGE_TAG}$"
                                        exit 0
                                        ;;
                                    Degraded)
                                        exit 1
                                        ;;
                                esac

                                sleep 10
                            done
                        '
                    '''
                }
            }
        }

        stage('Validate STAGE') {
            steps {
                container('tools') {
                    sh '''
                        set -eu
                        chmod +x scripts/smoke-test.sh
                        scripts/smoke-test.sh stage
                    '''
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

Promote image:

${env.IMAGE_URI}

to production through Helm and Argo CD?
""",
                    ok: 'Promote to Production'
                )
            }
        }

        stage('Update PROD Helm Values') {
            steps {
                container('yq') {
                    sh '''
                        set -eu

                        yq -i \
                          '.image.repository = strenv(ECR_REGISTRY)'\
' + "/" + strenv(ECR_REPOSITORY)' \
                          "${PROD_VALUES_FILE}"

                        yq -i \
                          '.image.tag = strenv(IMAGE_TAG)' \
                          "${PROD_VALUES_FILE}"

                        yq -i \
                          '.image.pullPolicy = "IfNotPresent"' \
                          "${PROD_VALUES_FILE}"

                        yq '.image' "${PROD_VALUES_FILE}"
                    '''
                }
            }
        }

        stage('Validate PROD Helm Chart') {
            steps {
                container('helm') {
                    sh '''
                        set -eu

                        helm lint "${HELM_CHART}" \
                            -f "${PROD_VALUES_FILE}"

                        helm template "${PROD_ARGO_APP}" \
                            "${HELM_CHART}" \
                            -f "${PROD_VALUES_FILE}" \
                            > rendered-prod.yaml

                        grep -q '^kind: Rollout$' \
                            rendered-prod.yaml

                        grep -q "${IMAGE_TAG}" \
                            rendered-prod.yaml
                    '''
                }
            }
        }

        stage('Commit PROD GitOps Change') {
            steps {
                container('jnlp') {
                    withCredentials([
                        usernamePassword(
                            credentialsId:
                                "${GITHUB_CREDENTIALS_ID}",
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_TOKEN'
                        )
                    ]) {
                        sh '''
                            set -eu

                            git add "${PROD_VALUES_FILE}"

                            if git diff --cached --quiet; then
                                echo "No PROD values change."
                                exit 0
                            fi

                            git commit \
                                -m "Promote ${IMAGE_TAG} to prod [skip ci]"

                            set +x

                            git push origin HEAD:main

                            set -x
                        '''
                    }
                }
            }
        }

        stage('Argo CD Sync PROD') {
            steps {
                container('argocd') {
                    sh '''
                        set -eu

                        argocd \
                            --core \
                            --kubeconfig "${KUBECONFIG}" \
                            --namespace argocd \
                            app sync "${PROD_ARGO_APP}" \
                            --prune \
                            --timeout 300

                        argocd \
                            --core \
                            --kubeconfig "${KUBECONFIG}" \
                            --namespace argocd \
                            app wait "${PROD_ARGO_APP}" \
                            --sync \
                            --health \
                            --timeout 300
                    '''
                }
            }
        }

        stage('Wait for PROD Rollout') {
            steps {
                container('tools') {
                    sh '''
                        set -eu

                        timeout 360 sh -c '
                            while true; do
                                IMAGE="$(
                                    kubectl \
                                      --kubeconfig \
                                        "${KUBECONFIG}" \
                                      -n "${PROD_NAMESPACE}" \
                                      get rollout \
                                        "${PROD_ROLLOUT}" \
                                      -o jsonpath="{.spec.template.spec.containers[0].image}"
                                )"

                                PHASE="$(
                                    kubectl \
                                      --kubeconfig \
                                        "${KUBECONFIG}" \
                                      -n "${PROD_NAMESPACE}" \
                                      get rollout \
                                        "${PROD_ROLLOUT}" \
                                      -o jsonpath="{.status.phase}"
                                )"

                                echo \
                                  "PROD image=${IMAGE}, phase=${PHASE}"

                                case "${PHASE}" in
                                    Healthy)
                                        echo "${IMAGE}" |
                                            grep -q \
                                            ":${IMAGE_TAG}$"
                                        exit 0
                                        ;;
                                    Degraded)
                                        exit 1
                                        ;;
                                esac

                                sleep 10
                            done
                        '
                    '''
                }
            }
        }

        stage('Validate PROD') {
            steps {
                container('tools') {
                    sh '''
                        set -eu
                        chmod +x scripts/smoke-test.sh
                        scripts/smoke-test.sh prod
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
            echo "ECR image: ${env.IMAGE_URI}"
            echo "Terraform changes: ${env.TERRAFORM_CHANGES}"
            echo '''
The image was promoted through DEV, STAGE and PROD.

Jenkins:
- tested the application
- managed Terraform
- built the image with Kaniko
- pushed it to Amazon ECR
- scanned it with Trivy
- validated the Helm chart
- updated the environment values

Argo CD:
- rendered the Helm chart
- synchronized the applications to Amazon EKS

Argo Rollouts:
- performed the canary deployments
'''
        }

        failure {
            echo 'Pipeline failed. Check the failed stage.'
        }

        aborted {
            echo '''
Pipeline was aborted, timed out, or production promotion
was not approved.
'''
        }

        always {
            archiveArtifacts(
                artifacts:
                    "${TERRAFORM_DIRECTORY}/" +
                    "${TERRAFORM_PLAN_TEXT}," +
                    "rendered-*.yaml",
                fingerprint: true,
                allowEmptyArchive: true
            )

            echo "Build result: ${currentBuild.currentResult}"
        }
    }
}