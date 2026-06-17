# Final Project - CI/CD & GitOps Pipeline

## Author

Eshed Porat

---

# Project Overview

This project demonstrates a complete cloud-native CI/CD and GitOps workflow for a containerized Flask application running on Kubernetes.

The application is a simple Flask web server that displays:

```text
Hello World
```

The solution implements:

* Jenkins running inside Kubernetes
* Docker image builds using Kaniko
* Docker Hub image registry integration
* Trivy vulnerability scanning
* Helm-based application packaging
* Multi-environment deployments (DEV, STAGE, PROD)
* Manual promotion gates between environments
* Argo Rollouts Canary deployments
* Horizontal Pod Autoscaler (HPA)
* GitOps-ready Argo CD application definitions

At the end of the project, the application is successfully deployed and running in three independent Kubernetes environments:

* DEV
* STAGE
* PROD

using Helm, Argo Rollouts, and Jenkins-driven CI/CD automation.

---

# Repository Structure

```text
Final-Project
├── app/
│   ├── app.py
│   └── requirements
│
├── argocd/
│   ├── apps/
│   │   ├── dev.yaml
│   │   ├── prod.yaml
│   │   └── stage.yaml
│   └── app-of-apps.yaml
│
├── environments/
│   ├── dev/
│   │   └── values.yaml
│   ├── prod/
│   │   └── values.yaml
│   └── stage/
│       └── values.yaml
│
├── helm/
│   └── hello-world/
│       ├── templates/
│       │   ├── hpa.yaml
│       │   ├── rollout.yaml
│       │   └── service.yaml
│       ├── Chart.yaml
│       └── values.yaml
│
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
│
├── results/
│   ├── advanced/
│   │   ├── Pipeline Console Output.txt
│   │   └── Pipeline Success.png
│   │
│   ├── k8s status/
│   │   └── cluster-status.txt
│   │
│   └── mandatory/
│       ├── Pipeline Console Output.txt
│       └── Pipeline Success.png
│
├── Dockerfile
├── Jenkinsfile
└── README.md
```

---

# Application

The application is written in Flask and serves a simple web page.

Application source:

```text
app/app.py
```

---

# Mandatory Requirements

## Source Control

The complete project is stored in GitHub and includes:

* Application source code
* Dockerfile
* Jenkinsfile
* Kubernetes manifests
* Helm chart
* Environment configurations
* Documentation

Repository:

```text
https://github.com/OhWreckedcom10/Final-Project
```

---

## Jenkins CI/CD Pipeline

The Jenkins pipeline is executed inside Kubernetes using dynamic Jenkins agent pods.

Pipeline stages:

1. Checkout source code from GitHub
2. Build Docker image using Kaniko
3. Push image to Docker Hub
4. Perform Trivy security scanning
5. Deploy to DEV environment
6. Manual approval gate
7. Deploy to STAGE environment
8. Manual approval gate
9. Deploy to PROD environment

The deployment stages use Helm charts and environment-specific values files.

The pipeline only proceeds to the next environment after successful deployment and manual approval.

Pipeline definition:

```text
Jenkinsfile
```

---

## Docker Containerization

The application is packaged as a Docker image.

Docker build example:

```bash
docker build -t ohwrecked/final-project .
```

Docker run example:

```bash
docker run -p 5000:5000 ohwrecked/final-project
```

Docker Hub repository:

```text
ohwrecked/final-project
```

---

## Kubernetes Deployment

The project contains standard Kubernetes manifests under:

```text
k8s/
```

Files:

```text
deployment.yaml
service.yaml
```

The final deployment solution uses Helm and Argo Rollouts for progressive delivery.

The deployment includes:

* Multiple replicas
* Resource requests
* Resource limits
* Kubernetes Services
* Environment separation through namespaces

---

# Advanced Requirements

## Trivy Security Scanning

The Jenkins pipeline performs container security scanning using Trivy before deployment.

The scan is configured to fail the pipeline when CRITICAL application vulnerabilities are detected.

Security scanning is performed automatically before deployment to any environment.

---

## Helm

The application is packaged as a Helm chart.

Chart location:

```text
helm/hello-world
```

Files:

```text
Chart.yaml
values.yaml
templates/
```

Deployment example:

```bash
helm upgrade --install hello-world-dev \
  helm/hello-world \
  -f environments/dev/values.yaml \
  -n dev --create-namespace
```

---

## Multi-Environment Configuration

The repository contains configuration for three environments:

```text
environments/dev
environments/stage
environments/prod
```

The application is deployed into three independent Kubernetes namespaces:

```text
dev
stage
prod
```

Each environment uses a dedicated values file and defines:

* Replica counts
* Resource requests
* Resource limits
* Image configuration

The environments are promoted through the Jenkins pipeline using manual approval gates.

---

## Argo CD

Argo CD application definitions are stored in:

```text
argocd/apps/
```

Files:

```text
dev.yaml
stage.yaml
prod.yaml
```

The repository also contains:

```text
argocd/app-of-apps.yaml
```

which implements the App-of-Apps pattern for GitOps deployments.

---

## Argo Rollouts

Canary deployment configuration is defined in:

```text
helm/hello-world/templates/rollout.yaml
```

The rollout performs progressive deployment using multiple rollout stages.

Example rollout strategy:

* 20% traffic shift
* 50% traffic shift
* 100% traffic shift

Rollouts were successfully deployed and verified in:

* DEV
* STAGE
* PROD

environments.

---

## Horizontal Pod Autoscaler

The HPA configuration is defined in:

```text
helm/hello-world/templates/hpa.yaml
```

This enables automatic scaling of the application based on CPU utilization.

HPAs were successfully deployed in:

* DEV
* STAGE
* PROD

environments.

---

# Final Deployment State

After successful pipeline execution, the application was deployed into three Kubernetes environments.

| Environment | Namespace | Rollout | HPA | Pods |
|------------|-----------|---------|-----|------|
| DEV | dev | Enabled | Enabled | Running |
| STAGE | stage | Enabled | Enabled | Running |
| PROD | prod | Enabled | Enabled | Running |

Each environment contains:

* Argo Rollout resource
* Kubernetes Service
* Horizontal Pod Autoscaler
* Running application Pods

Deployment status was validated using Kubernetes commands and stored in:

```text
results/k8s status/cluster-status.txt
```

---

# Deployment Instructions

## Clone Repository

```bash
git clone https://github.com/OhWreckedcom10/Final-Project.git
cd Final-Project
```

## Build Docker Image

```bash
docker build -t ohwrecked/final-project .
```

## Deploy Using Helm

DEV:

```bash
helm upgrade --install hello-world-dev \
  helm/hello-world \
  -f environments/dev/values.yaml \
  -n dev --create-namespace
```

STAGE:

```bash
helm upgrade --install hello-world-stage \
  helm/hello-world \
  -f environments/stage/values.yaml \
  -n stage --create-namespace
```

PROD:

```bash
helm upgrade --install hello-world-prod \
  helm/hello-world \
  -f environments/prod/values.yaml \
  -n prod --create-namespace
```

---

# Challenges Encountered During Implementation

During the implementation of the project, several technical challenges were encountered and resolved.

The first challenge was deploying Jenkins inside Kubernetes. Jenkins was initially unavailable after cluster reconfiguration and had to be reinstalled and reconfigured. Additional troubleshooting was required to restore agent connectivity, Kubernetes integration, and Docker Hub authentication.

A second challenge involved building Docker images from within Jenkins running inside Kubernetes. Since Docker was not available inside the Jenkins agent containers, the solution was migrated to Kaniko, which allows container image builds without requiring a Docker daemon.

Authentication with Docker Hub also required additional configuration. Jenkins was initially unable to push images because the Docker Hub credentials and Kubernetes secrets were not correctly configured. This was resolved by creating and mounting Docker registry secrets that Kaniko could consume during image builds.

Several deployment issues were encountered during Kubernetes rollouts. New application versions occasionally failed to start correctly, causing deployments to exceed their rollout deadlines. Investigation of pod logs revealed application dependency issues, including missing Flask packages inside generated container images. The Dockerfile and build process were updated until the image was built consistently and deployed successfully.

Security scanning with Trivy introduced another challenge. Initial scans failed because the selected base images contained multiple CRITICAL operating system vulnerabilities. Different base images were evaluated and the Trivy configuration was adjusted to focus on application dependency vulnerabilities while still enforcing security controls in the CI/CD pipeline.

Additional troubleshooting was required when deploying Helm releases. Some releases entered a failed state due to namespace conflicts, missing permissions, service conflicts, and missing Argo Rollouts controllers after namespace cleanup. RBAC permissions were updated, controllers were reinstalled, and Helm releases were redeployed until all environments became healthy.

Throughout the project, Kubernetes logs, Jenkins console output, Helm validation commands, Docker image inspection, rollout monitoring, and Trivy scan results were used extensively to identify and resolve issues. These troubleshooting activities provided valuable hands-on experience with CI/CD pipelines, Kubernetes operations, GitOps workflows, progressive delivery, container security, and multi-environment deployment strategies.

---

# Results

The repository contains evidence demonstrating successful completion of the project requirements.

## Mandatory Requirements

Location:

```text
results/mandatory/
```

Contains:

* Pipeline Success Screenshot
* Pipeline Console Output

These files demonstrate successful completion of the mandatory CI/CD requirements.

---

## Advanced Requirements

Location:

```text
results/advanced/
```

Contains:

* Pipeline Success Screenshot
* Pipeline Console Output

These files demonstrate successful completion of the advanced CI/CD and GitOps requirements.

---

## Kubernetes Environment Status

Location:

```text
results/k8s status/
```

Contains:

* cluster-status.txt

This file contains the final Kubernetes deployment status after pipeline execution, including:

* DEV environment resources
* STAGE environment resources
* PROD environment resources
* Argo Rollouts
* Running Pods
* Services
* Horizontal Pod Autoscalers

The status output verifies that all environments were deployed successfully and were running with healthy replicas.

---

# Architecture

```text
GitHub
   │
   ▼
Jenkins CI/CD
   │
   ├── Kaniko Build
   ├── Trivy Security Scan
   └── Docker Hub Push
   │
   ▼
Helm Deployment
   │
   ├──────────────┬──────────────┬──────────────┐
   ▼              ▼              ▼
 DEV           STAGE           PROD
   │              │              │
   ▼              ▼              ▼
Rollout       Rollout        Rollout
HPA           HPA            HPA
Service       Service        Service
Pods          Pods           Pods
```

---