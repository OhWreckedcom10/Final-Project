# 🚀 Enterprise Cloud-Native CI/CD Platform

> End-to-end automated software delivery platform built with **Terraform**, **Amazon EKS**, **Kubernetes**, **Jenkins**, **GitOps**, **Helm**, and **Argo Rollouts**.

<p align="center">

![AWS](https://img.shields.io/badge/AWS-EKS-orange?style=for-the-badge&logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?style=for-the-badge&logo=terraform)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes)
![Jenkins](https://img.shields.io/badge/Jenkins-CI-D24939?style=for-the-badge&logo=jenkins)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?style=for-the-badge&logo=argo)
![Helm](https://img.shields.io/badge/Helm-v3-0F1689?style=for-the-badge&logo=helm)
![Docker](https://img.shields.io/badge/Docker-Hub-2496ED?style=for-the-badge&logo=docker)
![Python](https://img.shields.io/badge/Python-Flask-3776AB?style=for-the-badge&logo=python)

</p>

---

## 📖 Overview

This project demonstrates a **production-style cloud-native CI/CD platform** built around a hybrid Kubernetes architecture.

The platform automates the complete software delivery lifecycle:

- Provisioning AWS infrastructure with Terraform
- Building container images in Kubernetes with Kaniko
- Scanning images with Trivy
- Publishing images to ECR
- Updating Helm configuration
- Synchronizing Amazon EKS through Argo CD
- Deploying progressively with Argo Rollouts
- Promoting releases through DEV, STAGE, and PROD

The application is intentionally lightweight so the project can focus on the surrounding DevOps platform and deployment automation.

---

## ✨ Features

- ☁ Infrastructure as Code with Terraform
- ☸ Hybrid Kubernetes architecture using k3s and Amazon EKS
- 🚀 Jenkins CI pipeline with Kubernetes-based agents
- 📦 Daemonless container builds with Kaniko
- 🔒 Vulnerability scanning with Trivy
- 🐳 Docker Hub image registry
- 📋 Helm-based Kubernetes configuration
- 🌿 GitOps delivery with Argo CD
- 🚦 Progressive delivery with Argo Rollouts
- 📈 Horizontal Pod Autoscaling
- 🌍 Isolated DEV, STAGE, and PROD environments

---

## 🏗 Hybrid Architecture

```mermaid
flowchart LR
    DEV[Developer] -->|Git push| GH[GitHub Repository]

    subgraph ONPREM["On-Prem Kubernetes Cluster - k3s"]
        J[Jenkins Controller]
        JA[Jenkins Agent Pods]
        K[Kaniko]
        T[Trivy]
        J --> JA
        JA --> K
        K --> T
    end

    GH --> J
    T -->|Push versioned image| DH[(Docker Hub)]
    T -->|Update Helm values and commit| GITOPS[GitOps Repository]

    subgraph AWS["AWS Cloud"]
        subgraph EKS["Amazon EKS"]
            ACD[Argo CD]
            AR[Argo Rollouts]
            DEVNS[DEV Namespace]
            STAGENS[STAGE Namespace]
            PRODNS[PROD Namespace]
            MS[Metrics Server]

            ACD --> AR
            AR --> DEVNS
            AR --> STAGENS
            AR --> PRODNS
            MS --> DEVNS
            MS --> STAGENS
            MS --> PRODNS
        end
    end

    GITOPS -->|Desired state| ACD
    DH -->|Pull image| DEVNS
    DH -->|Pull image| STAGENS
    DH -->|Pull image| PRODNS
```

The on-premises k3s cluster is responsible for **Continuous Integration**, while Amazon EKS is responsible for **GitOps-based application delivery and runtime workloads**.

---

## 🔄 CI/CD Workflow

```mermaid
flowchart TD
    A[Developer commits code] --> B[GitHub]
    B --> C[Jenkins pipeline starts]
    C --> D[Checkout source code]
    D --> E[Run tests and validation]
    E --> F[Build image with Kaniko]
    F --> G[Scan image with Trivy]
    G --> H{Security scan passed?}

    H -->|No| X[Stop pipeline]
    H -->|Yes| I[Push image to Docker Hub]
    I --> J[Update Helm image tag]
    J --> K[Commit GitOps repository]
    K --> L[Argo CD hard refresh]
    L --> M[Argo CD sync]
    M --> N[Argo Rollouts deployment]
    N --> O[Deploy to DEV]
    O --> P[Smoke tests]
    P --> Q{Approve STAGE?}
    Q -->|Yes| R[Deploy to STAGE]
    Q -->|No| Y[Stop promotion]
    R --> S[Validation]
    S --> T{Approve PROD?}
    T -->|Yes| U[Deploy to PROD]
    T -->|No| Z[Keep current production version]
```

Jenkins does not directly manage the final Kubernetes deployment. It updates the desired state in Git, and Argo CD reconciles Amazon EKS with that state.

---

## ☁ Terraform and AWS Infrastructure

```mermaid
flowchart TD
    TF[Terraform] --> VPC[Amazon VPC]
    VPC --> PUB[Public Subnets]
    VPC --> PRIV[Private Subnets]
    TF --> IAM[IAM Roles and Policies]
    TF --> SG[Security Groups]
    TF --> EKS[Amazon EKS Control Plane]
    EKS --> NG[Managed Node Group]
    NG --> N1[Worker Node 1]
    NG --> N2[Worker Node 2]
    NG --> N3[Worker Node 3]
    PUB --> LB[AWS Load Balancer]
    PRIV --> N1
    PRIV --> N2
    PRIV --> N3
    LB --> SVC[Kubernetes Service]
    SVC --> PODS[Application Pods]
```

Terraform is used to create and maintain the AWS infrastructure declaratively, including networking, IAM, security rules, the EKS cluster, and worker nodes.

---

## 🌿 GitOps Workflow

```mermaid
sequenceDiagram
    participant Jenkins
    participant Git as GitOps Repository
    participant Argo as Argo CD
    participant EKS as Amazon EKS

    Jenkins->>Git: Update Helm image tag
    Jenkins->>Git: Commit and push
    Argo->>Git: Detect desired-state change
    Argo->>Argo: Hard refresh application
    Argo->>EKS: Synchronize resources
    EKS-->>Argo: Report live state
    Argo-->>Git: Desired and live state aligned
```

Git acts as the **single source of truth**. Manual cluster changes are discouraged because Argo CD continuously compares the live state with the declared configuration.

---

## 🚦 Progressive Delivery

```mermaid
flowchart LR
    OLD[Current stable version] --> NEW[Create new ReplicaSet]
    NEW --> CHECK[Run readiness and health checks]
    CHECK --> RESULT{Healthy?}
    RESULT -->|Yes| SHIFT[Shift workload to new version]
    SHIFT --> COMPLETE[Mark rollout successful]
    RESULT -->|No| ABORT[Abort rollout]
    ABORT --> ROLLBACK[Keep or restore stable version]
```

Argo Rollouts provides controlled releases and safer rollback behavior compared with immediate replacement of all application Pods.

---

## 🌍 Environment Promotion

```mermaid
flowchart LR
    DEV[DEV] -->|Smoke tests pass| APPROVE1{Manual approval}
    APPROVE1 -->|Approved| STAGE[STAGE]
    APPROVE1 -->|Rejected| STOP1[Stop promotion]
    STAGE -->|Validation passes| APPROVE2{Manual approval}
    APPROVE2 -->|Approved| PROD[PROD]
    APPROVE2 -->|Rejected| STOP2[Keep current production release]
```

Each environment is isolated in its own Kubernetes namespace, reducing the chance that a development or staging deployment affects production.

---

## 📈 Autoscaling

```mermaid
flowchart TD
    MS[Metrics Server] --> CPU[Collect CPU and memory metrics]
    CPU --> HPA[Horizontal Pod Autoscaler]
    HPA --> LOAD{Resource usage}
    LOAD -->|Below target| KEEP[Keep minimum replicas]
    LOAD -->|Above target| SCALEUP[Increase replicas]
    LOAD -->|Demand decreases| SCALEDOWN[Reduce replicas]
    SCALEUP --> PODS[Application Pods]
    SCALEDOWN --> PODS
    KEEP --> PODS
```

The Horizontal Pod Autoscaler adjusts the number of application Pods based on current resource usage.

---

## 🌐 Request Flow

```mermaid
flowchart LR
    USER[User] --> INTERNET[Internet]
    INTERNET --> ALB[AWS Load Balancer]
    ALB --> SVC[Kubernetes Service]
    SVC --> ROLLOUT[Argo Rollout]
    ROLLOUT --> P1[Application Pod 1]
    ROLLOUT --> P2[Application Pod 2]
    ROLLOUT --> PN[Additional Pods]
```

The Load Balancer exposes the application externally and distributes requests through the Kubernetes Service to healthy Pods.

---

## 🛠 Technology Stack

| Category | Technology |
|---|---|
| Cloud Provider | AWS |
| Infrastructure as Code | Terraform |
| Production Kubernetes | Amazon EKS |
| CI Kubernetes | k3s |
| Continuous Integration | Jenkins |
| Container Build | Kaniko |
| Vulnerability Scanning | Trivy |
| Container Registry | Docker Hub |
| Kubernetes Packaging | Helm |
| GitOps | Argo CD |
| Progressive Delivery | Argo Rollouts |
| Autoscaling | Horizontal Pod Autoscaler |
| Application | Python Flask |

---

## 📂 Repository Structure

```text
.
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── helm/
│   └── flask-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│
├── kubernetes/
│
├── Jenkinsfile
│
├── docs/
│   ├── FULL_DOCUMENTATION.md
│   ├── ARCHITECTURE.md
│   ├── PIPELINE.md
│   ├── TROUBLESHOOTING.md
│   └── screenshots/
│
└── README.md
```

---

## 🚀 Deployment Summary

1. Terraform provisions the AWS infrastructure and Amazon EKS cluster.
2. Jenkins receives or detects a source-code change.
3. A Kubernetes-based Jenkins agent executes the pipeline.
4. Kaniko builds a uniquely tagged container image.
5. Trivy scans the image for known vulnerabilities.
6. The image is pushed to Docker Hub.
7. Jenkins updates the Helm image tag in Git.
8. Argo CD refreshes and synchronizes the application.
9. Argo Rollouts deploys the new version.
10. The release is promoted through DEV, STAGE, and PROD.

---

## 📸 Screenshots

Add screenshots from the live environment under `docs/screenshots/`.

| Component | Suggested file |
|---|---|
| Terraform Apply | `docs/screenshots/terraform-apply.png` |
| Amazon EKS | `docs/screenshots/eks-cluster.png` |
| Jenkins Pipeline | `docs/screenshots/jenkins-pipeline.png` |
| Docker Hub | `docs/screenshots/docker-hub.png` |
| Argo CD | `docs/screenshots/argocd.png` |
| Argo Rollouts | `docs/screenshots/argo-rollouts.png` |
| Kubernetes Pods | `docs/screenshots/pods.png` |
| HPA | `docs/screenshots/hpa.png` |
| Running Application | `docs/screenshots/application.png` |

---

## 📚 Documentation

Detailed implementation, architecture, troubleshooting, security, and deployment explanations are available in:

- **[Full Project Documentation](docs/FULL_DOCUMENTATION.md)**
- **[Architecture Guide](docs/ARCHITECTURE.md)**
- **[CI/CD Pipeline Guide](docs/PIPELINE.md)**
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**

---

## 🎯 Learning Outcomes

This project demonstrates practical experience with:

- Infrastructure as Code
- AWS networking and Amazon EKS
- Kubernetes administration
- CI/CD pipeline development
- Kubernetes-native image building
- Container vulnerability scanning
- Helm packaging
- GitOps reconciliation
- Progressive delivery
- Multi-environment promotion
- Kubernetes networking and autoscaling
- Real-world troubleshooting

---

## 👨‍💻 Author

**Eshed Porat**

Cloud · DevOps · Kubernetes · AWS · Automation
