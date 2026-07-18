# 🚀 Final Project -- Cloud-Native CI/CD, GitOps & Infrastructure as Code

**Author:** Eshed Porat

![AWS](https://img.shields.io/badge/AWS-EKS-orange)
![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.36-326CE5)
![Jenkins](https://img.shields.io/badge/CI-Jenkins-D24939)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D)
![Helm](https://img.shields.io/badge/Helm-v3-0F1689)

------------------------------------------------------------------------

# 📖 Project Overview

This project demonstrates a complete **enterprise-style cloud-native
DevOps platform** that automates the entire software delivery
lifecycle---from infrastructure provisioning to production deployment.

The solution combines **Infrastructure as Code (Terraform)**,
**Continuous Integration (Jenkins)**, **GitOps (Argo CD)** and
**Progressive Delivery (Argo Rollouts)** to deploy a containerized Flask
application into **Amazon EKS**.

## Key Features

-   Terraform Infrastructure as Code
-   Hybrid Kubernetes Architecture
-   Amazon EKS
-   Jenkins CI/CD
-   Kaniko container builds
-   Trivy image scanning
-   Docker Hub integration
-   Helm packaging
-   GitOps with Argo CD
-   Canary deployments with Argo Rollouts
-   Horizontal Pod Autoscaler
-   DEV / STAGE / PROD environments

------------------------------------------------------------------------

# 🏗 Architecture

``` text
Developer
    │
    ▼
GitHub Repository
    │
    ▼
────────────────── On-Prem Kubernetes ──────────────────

 Jenkins Controller
 Jenkins Agent Pods
 Kaniko
 Trivy

──────────────────────┬────────────────────────
                       │
                 Docker Hub
                       │
                GitOps Update
                       │
                       ▼

──────────────────── AWS Cloud ─────────────────────────

Terraform
   │
   ▼
AWS VPC • IAM • Security Groups
   │
   ▼
Amazon EKS
(Managed Control Plane)
   │
   ▼
3 EC2 Worker Nodes
   │
   ▼
Argo CD
Argo Rollouts
   │
   ▼
DEV      STAGE      PROD
```

------------------------------------------------------------------------

# ☁ Hybrid Kubernetes Architecture

## On-Premises Cluster (k3s)

The first Kubernetes cluster is hosted on-premises and is dedicated to
the Continuous Integration platform.

It hosts:

-   Jenkins Controller
-   Dynamic Jenkins Agent Pods
-   Kaniko
-   Trivy

Responsibilities include:

-   Building Docker images
-   Vulnerability scanning
-   Updating the GitOps repository
-   Orchestrating deployments

------------------------------------------------------------------------

## AWS Cloud Cluster

The production platform is hosted on **Amazon Elastic Kubernetes Service
(EKS)**.

Terraform provisions the complete cloud infrastructure including:

-   Amazon VPC
-   IAM Roles
-   Security Groups
-   Amazon EKS
-   Managed Node Group
-   **3 EC2 Worker Nodes**
-   Elastic Load Balancer

Inside the cluster are:

-   Argo CD
-   Argo Rollouts
-   CoreDNS
-   kube-proxy
-   Metrics Server
-   AWS VPC CNI

The application is deployed into three isolated namespaces:

-   DEV
-   STAGE
-   PROD

Each namespace contains:

-   Deployment / Rollout
-   Kubernetes Service
-   HPA
-   Dedicated configuration

------------------------------------------------------------------------

# 🏗 Terraform Infrastructure

Terraform provisions the AWS infrastructure.

Resources include:

-   VPC
-   Networking
-   Security Groups
-   IAM
-   Amazon EKS
-   Worker Nodes

Workflow:

``` bash
terraform init
terraform plan
terraform apply
```

------------------------------------------------------------------------

# ⚙ CI/CD Pipeline

1.  Checkout source
2.  Build image using Kaniko
3.  Trivy security scan
4.  Push image to Docker Hub
5.  Update Helm values
6.  Commit GitOps changes
7.  Push to GitHub
8.  Argo CD synchronization
9.  Deploy DEV
10. Smoke Test
11. Deploy STAGE
12. Smoke Test
13. Manual Approval
14. Deploy PROD
15. Smoke Test

------------------------------------------------------------------------

# 🔄 GitOps Workflow

Jenkins never deploys directly to Kubernetes.

Instead it updates the GitOps repository.

Argo CD continuously monitors Git and synchronizes the desired state to
Amazon EKS.

Argo Rollouts performs progressive canary deployments.

------------------------------------------------------------------------

# ☸ Kubernetes Deployment

Deployment technologies:

-   Helm
-   Argo CD
-   Argo Rollouts
-   HPA
-   Kubernetes Services
-   Namespaces

------------------------------------------------------------------------

# 🔒 Security

Security controls include:

-   Trivy image scanning
-   IAM Roles
-   Security Groups
-   Kubernetes namespaces
-   GitOps deployment model

------------------------------------------------------------------------

# 📊 Final Environment

  Environment   Namespace   Status
  ------------- ----------- ---------
  DEV           dev         Healthy
  STAGE         stage       Healthy
  PROD          prod        Healthy

------------------------------------------------------------------------

# ⚠ Challenges

Highlights:

-   Kaniko container builds
-   Terraform provisioning
-   Amazon EKS networking
-   Docker Hub authentication
-   Argo CD synchronization timing
-   Kubernetes Service selector troubleshooting
-   AWS Load Balancer configuration
-   Multi-environment GitOps deployment

------------------------------------------------------------------------

# 🚀 Future Improvements

-   Monitoring with Prometheus & Grafana
-   Automated rollback policies
-   TLS with cert-manager
-   External Secrets
-   Automated integration testing