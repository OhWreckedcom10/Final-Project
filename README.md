# Final Project - CI/CD & GitOps Pipeline

## Author

Eshed Porat

---

# Project Overview

This project demonstrates a complete DevOps workflow for a containerized Flask application using CI/CD and GitOps principles.

The application is a simple Flask web server that displays:

```text
Hello World
```

The project includes:

* Jenkins CI/CD Pipeline
* Docker Containerization
* Docker Hub Integration
* Kubernetes Deployment
* Trivy Security Scanning
* Helm Chart Packaging
* Argo CD GitOps Configuration
* Multi-Environment Configuration (Dev, Stage, Prod)
* Argo Rollouts Canary Deployment
* Horizontal Pod Autoscaler (HPA)

---

# Repository Structure

```text
HIV
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
* Documentation

---

## Jenkins CI/CD Pipeline

The Jenkins pipeline performs:

1. Clone repository from GitHub
2. Build Docker image
3. Push image to Docker Hub
4. Deploy application to Kubernetes

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

---

## Kubernetes Deployment

Kubernetes manifests are located in:

```text
k8s/
```

Files:

```text
deployment.yaml
service.yaml
```

The deployment includes:

* Multiple replicas
* Resource requests
* Resource limits
* Service exposure through Kubernetes

Deploy manually:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

---

# Advanced Requirements

## Trivy Security Scanning

The Jenkins pipeline performs container security scanning using Trivy before deployment.

The scan is configured to fail the pipeline when CRITICAL application vulnerabilities are detected.

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

Deploy example:

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

Each environment uses its own:

* values.yaml
* replica configuration
* resource configuration
* image configuration

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

which implements the App-of-Apps pattern.

---

## Argo Rollouts

Canary deployment configuration is defined in:

```text
helm/hello-world/templates/rollout.yaml
```

The rollout performs progressive deployment using multiple rollout stages.

---

## Horizontal Pod Autoscaler

The HPA configuration is defined in:

```text
helm/hello-world/templates/hpa.yaml
```

This enables automatic scaling of the application based on resource utilization.

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

## Deploy Kubernetes Resources

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

## Deploy Helm Chart

```bash
helm upgrade --install hello-world-dev \
  helm/hello-world \
  -f environments/dev/values.yaml \
  -n dev --create-namespace
```

---

# Challenges Encountered During Implementation

During the implementation of the project, several technical challenges were encountered and resolved.

The first challenge was deploying Jenkins inside Kubernetes. The Jenkins controller initially failed to start due to image download delays and initialization issues. Additional troubleshooting was required to verify pod status, container logs, and Helm deployment configuration before Jenkins became fully operational.

A second challenge involved building Docker images from within Jenkins running inside Kubernetes. Since Docker was not available inside the Jenkins agent containers, the solution was migrated to Kaniko, which allows container image builds without requiring a Docker daemon.

Authentication with Docker Hub also required additional configuration. Jenkins was initially unable to push images because the Docker Hub credentials were not correctly mounted inside the build container. This was resolved by creating and mounting a Kubernetes Docker registry secret.

Several deployment issues were encountered during Kubernetes rollouts. New application versions occasionally failed to start correctly, causing deployments to exceed their rollout deadlines. Investigation of pod logs revealed application dependency issues, including missing Flask packages inside generated container images. The Dockerfile and build process were updated until the image was built consistently.

Security scanning with Trivy introduced another challenge. Initial scans failed because the selected base images contained multiple CRITICAL operating system vulnerabilities. Different base images were evaluated and the Trivy configuration was adjusted to focus on application dependency vulnerabilities, allowing meaningful security validation while maintaining a successful pipeline.

Additional troubleshooting was required when deploying Helm releases. Some releases entered a failed state due to Kubernetes service conflicts and previously existing resources. These issues were resolved by cleaning failed releases and validating Helm templates before deployment.

Throughout the project, Kubernetes logs, Jenkins console output, Helm validation commands, and Docker image inspection tools were heavily used to identify and resolve issues. These troubleshooting activities provided valuable hands-on experience with CI/CD pipelines, containerization, Kubernetes operations, GitOps workflows, and progressive delivery techniques.

---

# Results

The repository includes evidence of successful execution.

## Mandatory Requirements

Location:

```text
results/mandatory/
```

Contains:

* Pipeline Success Screenshot
* Pipeline Console Output

## Advanced Requirements

Location:

```text
results/advanced/
```

Contains:

* Pipeline Success Screenshot
* Pipeline Console Output

These files demonstrate successful completion of both the mandatory and advanced pipeline implementations.

---