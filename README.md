# Final Project - CI/CD & Kubernetes Deployment

## Project Overview

This project demonstrates a complete CI/CD pipeline using Jenkins, Docker, Docker Hub, and Kubernetes.

The application is a simple Flask web application that displays:

Hello World

### Technologies Used

* Python Flask
* Docker
* Docker Hub
* Jenkins
* Kubernetes
* GitHub

### Project Structure

```text
.
├── app/
│   └── app.py
├── Dockerfile
├── Jenkinsfile
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── requirements.txt
└── README.md
```

---

## CI/CD Pipeline

The Jenkins pipeline performs the following steps:

1. Clone the GitHub repository
2. Build the application
3. Build a Docker image
4. Tag the Docker image
5. Push the image to Docker Hub
6. Deploy the application to Kubernetes

Docker Image Repository:

```text
ohwrecked/final-project
```

---

## Jenkins Pipeline Screenshot

Insert a screenshot of a successful Jenkins build here.

Example:

```text
README.md
└── screenshots/
    └── successful-pipeline.png
```

### Successful Build

![Jenkins Pipeline](screenshots/successful-pipeline.png)

---

## Deployment Instructions

### Prerequisites

* Docker installed
* Kubernetes cluster running
* kubectl configured
* Jenkins installed
* Docker Hub account

### Clone Repository

```bash
git clone https://github.com/OhWreckedcom10/Final-Project.git
cd Final-Project
```

### Build Docker Image

```bash
docker build -t ohwrecked/final-project:v1 .
```

### Push Docker Image

```bash
docker push ohwrecked/final-project:v1
```

### Deploy to Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Verify Deployment

```bash
kubectl get deployments
kubectl get pods
kubectl get svc
```

### Access Application

```text
http://<NODE-IP>:30080
```

or

```text
http://localhost:30080
```

---

## Kubernetes Configuration

### Deployment

* 2 replicas
* Resource requests configured
* Resource limits configured

### Service

* NodePort service
* Accessible from a web browser

---

## Troubleshooting

### Pod Not Starting

Check pod status:

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

View logs:

```bash
kubectl logs <pod-name>
```

---

### Image Pull Error

Verify image exists in Docker Hub:

```bash
docker pull ohwrecked/final-project:latest
```

Check deployment image:

```bash
kubectl describe deployment final-project
```

---

### Service Not Accessible

Verify service:

```bash
kubectl get svc
```

Verify NodePort:

```bash
kubectl describe svc final-project-service
```

Check application logs:

```bash
kubectl logs deployment/final-project
```

---

### Jenkins Build Failure

Check Jenkins Console Output for:

* Git clone errors
* Docker login errors
* Docker push errors
* Kubernetes deployment errors

Verify Jenkins credentials:

```text
dockerhub-creds
```

Verify Docker Hub access token is valid.

---

## Author

Eshed Porat

Final Project – CI/CD & GitOps Pipeline
