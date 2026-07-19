# 🚀 Enterprise Cloud-Native CI/CD Platform

> A production-style cloud-native CI/CD platform demonstrating Infrastructure as Code, Kubernetes, GitOps, Progressive Delivery, and automated deployments on AWS.

<p align="center">

![AWS](https://img.shields.io/badge/AWS-EKS-orange?style=for-the-badge&logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?style=for-the-badge&logo=terraform)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes)
![Jenkins](https://img.shields.io/badge/Jenkins-CI-D24939?style=for-the-badge&logo=jenkins)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?style=for-the-badge&logo=argo)
![Helm](https://img.shields.io/badge/Helm-v3-0F1689?style=for-the-badge&logo=helm)
![Amazon ECR](https://img.shields.io/badge/Amazon-ECR-FF9900?style=for-the-badge&logo=amazonaws)
![Python](https://img.shields.io/badge/Python-Flask-3776AB?style=for-the-badge&logo=python)

</p>

---

# 📖 Overview

This repository demonstrates a complete enterprise-style CI/CD platform built on a **hybrid Kubernetes architecture**.

The CI platform runs on an **on-premises k3s cluster**, while application workloads are deployed to **Amazon Elastic Kubernetes Service (EKS)**.

The platform automates the entire software delivery lifecycle—from provisioning cloud infrastructure with Terraform, through secure container image creation and vulnerability scanning, to GitOps-based deployments using Argo CD and Progressive Delivery with Argo Rollouts.

Rather than focusing on the application itself, this project demonstrates modern DevOps practices commonly used in enterprise production environments.

---

# 🏗 Hybrid Architecture

Unlike traditional cloud-only CI/CD platforms, this solution separates Continuous Integration from application runtime.

The CI infrastructure executes inside an **on-premises Kubernetes (k3s)** cluster while the deployed application runs inside **Amazon EKS**.

This architecture reflects common enterprise deployments where internal build infrastructure remains on-premises while production workloads leverage cloud scalability.

```mermaid
flowchart LR

subgraph OnPrem["On-Premises (k3s Cluster)"]

Jenkins[Jenkins]

Agent[Kubernetes Jenkins Agent]

Kaniko[Kaniko]

Trivy[Trivy]

end

subgraph AWS["AWS Cloud"]

ECR[Amazon ECR]

GitOps[Git Repository]

ArgoCD[Argo CD]

Rollouts[Argo Rollouts]

EKS[Amazon EKS]

end

Jenkins --> Agent

Agent --> Kaniko

Kaniko --> Trivy

Trivy --> ECR

ECR --> GitOps

GitOps --> ArgoCD

ArgoCD --> Rollouts

Rollouts --> EKS
```

---

# 🌍 Kubernetes Environment Separation

To simulate a production-grade deployment strategy, the application is deployed into three isolated Kubernetes environments.

| Environment | Purpose |
|------------|---------|
| **DEV** | Development and functional validation |
| **STAGE** | Integration testing and release verification |
| **PROD** | Stable production deployment |

Each namespace contains its own:

- Deployment / Rollout
- Service
- Horizontal Pod Autoscaler
- Helm Release

This separation enables safe release promotion while keeping production isolated from development activities.

```mermaid
flowchart LR

DEV["DEV Namespace"]

STAGE["STAGE Namespace"]

PROD["PROD Namespace"]

DEV -->|"Validated Release"| STAGE

STAGE -->|"Approved Release"| PROD
```

---

# 🔄 CI/CD Pipeline

The following diagram illustrates the complete software delivery lifecycle from source code to production deployment.

```mermaid
flowchart LR

A["👨‍💻 Developer"] -->|"Git Push"| B["GitHub"]

B -->|"Trigger Pipeline"| C["Jenkins"]

C -->|"Launch Agent"| D["Kubernetes Agent"]

D -->|"Build Image"| E["Kaniko"]

E -->|"Security Scan"| F["Trivy"]

F -->|"Push Image"| G["Amazon ECR"]

G -->|"Update Image Tag"| H["Helm Values"]

H -->|"Commit"| I["GitOps Repository"]

I -->|"Detect Changes"| J["Argo CD"]

J -->|"Synchronize"| K["Amazon EKS"]

K -->|"Progressive Deployment"| L["Argo Rollouts"]

L --> DEV

DEV -->|"Validation"| STAGE

STAGE -->|"Approval"| PROD
```

---

# 📖 Pipeline Overview

### ① Developer Commit

A developer pushes source code to the GitHub repository.

---

### ② Continuous Integration

Jenkins automatically detects the commit and launches a Kubernetes-based Jenkins Agent inside the on-premises k3s cluster.

---

### ③ Container Build

Kaniko builds the application container image without requiring a Docker daemon.

---

### ④ Security Scan

Trivy scans the container image for known vulnerabilities before allowing deployment.

---

### ⑤ Amazon ECR

Successfully validated images are published to Amazon Elastic Container Registry (ECR).

---

### ⑥ Helm Update

The pipeline updates the Helm chart with the newly generated image tag.

---

### ⑦ GitOps

The updated Helm configuration is committed to the GitOps repository, making Git the single source of truth.

---

### ⑧ Argo CD

Argo CD detects repository changes and synchronizes the desired state with Amazon EKS.

---

### ⑨ Progressive Delivery

Argo Rollouts deploys the application gradually, reducing deployment risk and enabling controlled rollbacks.

---

### ⑩ Environment Promotion

Validated releases move through:

**DEV → STAGE → PROD**

ensuring every release is verified before reaching production.

---

# 🛠 Technology Stack

| Category | Technology | Purpose |
|-----------|------------|---------|
| Cloud | AWS | Cloud Infrastructure |
| Infrastructure | Terraform | Infrastructure as Code |
| Kubernetes | Amazon EKS + k3s | Container Orchestration |
| CI | Jenkins | Pipeline Automation |
| Image Build | Kaniko | Daemonless Image Builds |
| Security | Trivy | Vulnerability Scanning |
| Registry | Amazon ECR | Container Registry |
| GitOps | Argo CD | Cluster Synchronization |
| Progressive Delivery | Argo Rollouts | Controlled Deployments |
| Package Manager | Helm | Kubernetes Package Management |
| Application | Python Flask | Demo Application |

---

# 📂 Repository Structure

```text
.
├── app/                 Application source code
├── terraform/           AWS infrastructure
├── helm/                Helm charts
├── kubernetes/          Kubernetes manifests
├── Jenkinsfile          Jenkins pipeline
├── docs/
│   └── FULL_DOCUMENTATION.md
└── README.md
```

# 📚 Documentation

This README provides a high-level overview of the platform.

For detailed implementation steps, architecture decisions, Terraform configuration, troubleshooting guides, and deployment procedures, see:

**📖 FULL_DOCUMENTATION.md**