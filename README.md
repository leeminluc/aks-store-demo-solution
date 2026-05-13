# AKS Store Demo Solution

This repository contains the CI/CD pipelines and infrastructure code for deploying the AKS Store Demo application to Azure Kubernetes Service (AKS).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Infrastructure Setup with Terraform](#infrastructure-setup-with-terraform)
- [Running Locally with Docker Compose](#running-locally-with-docker-compose)
- [Azure DevOps Configuration](#azure-devops-configuration)
- [Project Structure](#project-structure)

---

## Prerequisites

### For Running the app Locally

| Tool | Version | Description |
|------|---------|-------------|
| Docker | 20.x+ | Container runtime |
| Docker Compose | 2.x+ | Multi-container orchestration |

### For Azure DevOps Pipelines

| Requirement | Description |
|-------------|-------------|
| Azure Subscription | With Owner or Contributor access |
| Azure DevOps Organization | Create at [dev.azure.com](https://dev.azure.com) |
| Azure DevOps Project | Create a new project for this solution |
| GitHub Account | For accessing the source repository |

### Azure Resources Required

Before running the pipelines, ensure you have:

- **Azure Container Registry (ACR)** - For storing Docker images
- **Azure Kubernetes Service (AKS)** - Target Kubernetes cluster
- **Resource Group** - Containing the above resources

---

## Infrastructure Setup with Terraform

The infrastructure (AKS cluster, ACR, Resource Group) can be created using Terraform.

### Prerequisites for Terraform

| Tool | Description |
|------|-------------|
| Terraform | >= 1.0 |
| Azure CLI | Authenticated with `az login` |


### Deploy and Access Infrastructure

1. **Navigate to the terraform directory:**
   ```bash
   cd terraform
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the deployment plan:**
   ```bash
   terraform plan -out main.tfplan
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply main.tfplan
   ```

5. **Get AKS credentials:**
   ```bash
   az aks get-credentials \
     --resource-group <resource-group-name> \
     --name <aks-cluster-name>
   ```

---

## Running Locally with Docker Compose

### Quick Start

1. **Navigate to the docker directory:**
   ```bash
   cd docker
   ```

2. **Start all services:**
   ```bash
   docker-compose up -d
   ```

3. **Verify services are running:**
   ```bash
   docker-compose ps
   ```

4. **Access the application:**
   - **Store Front:** http://localhost:8080
   - **RabbitMQ Management:** http://localhost:15672 (username: `username`, password: `password`)

5. **Stop all services:**
   ```bash
   docker-compose down
   ```

---

## Azure DevOps Configuration

### Step 1: Create Service Connections

Navigate to **Project Settings > Service connections** and create the following:

#### 1.1 GitHub Connection

| Field | Value |
|-------|-------|
| Connection type | GitHub |
| Connection name | `github-connection` |
| Authentication | OAuth or Personal Access Token |

This connection allows the pipeline to fetch source code from `Azure-Samples/aks-store-demo`.

#### 1.2 Azure Container Registry Connection

| Field | Value |
|-------|-------|
| Connection type | Docker Registry |
| Connection name | `acr-connection` |
| Registry type | Azure Container Registry |
| Azure subscription | Your subscription |
| Azure Container Registry | Your ACR instance |

This connection allows the pipeline to push Docker images to your ACR.

#### 1.3 Azure Resource Manager Connection

| Field | Value |
|-------|-------|
| Connection type | Azure Resource Manager |
| Connection name | `azure-connection` |
| Authentication method | Service principal (automatic) |
| Scope level | Subscription |
| Subscription | Your subscription |

This connection allows the pipeline to deploy to AKS.

---

### Step 2: Create Variable Group

Navigate to **Pipelines > Library** and create a variable group named `aks-store-demo-variables`:

| Variable Name | Example Value | Description |
|---------------|---------------|-------------|
| `containerRegistryName` | `acrdemozebra95` | ACR name (without .azurecr.io) |
| `containerRegistry` | `acrdemozebra95.azurecr.io` | Full ACR login server URL |
| `resourceGroup` | `rg-demozebra95` | Resource group name |
| `aksCluster` | `aks-demozebra95` | AKS cluster name |

---

### Step 3: Import Pipelines

#### 3.1 Import CI Pipeline

1. Go to **Pipelines > Create Pipeline**
2. Select **Azure Repos Git** (or your Git provider)
3. Select your repository
4. Select **Existing Azure Pipelines YAML file**
5. Select the branch and path: `/azure-pipelines/azure-pipelines-ci.yml`
6. Click **Save** (don't run yet)

#### 3.2 Import CD Pipeline

1. Go to **Pipelines > Create Pipeline**
2. Select **Azure Repos Git** (or your Git provider)
3. Select your repository
4. Select **Existing Azure Pipelines YAML file**
5. Select the branch and path: `/azure-pipelines/azure-pipelines-cd.yml`
6. Click **Save** (don't run yet)


---

### Step 4: Run the Pipelines

1. **Run the CI Pipeline first:**
   - Go to Pipelines
   - Select the CI pipeline
   - Click **Run pipeline**
   - This will build and push Docker images to ACR

2. **Run the CD Pipeline:**
   - The CD pipeline will trigger automatically after CI completes
   - Or manually run it from the Pipelines page

---

## Pipeline Overview

### CI Pipeline (`azure-pipelines-ci.yml`)

The CI pipeline follows the **Test → Push** pattern:

1. **Test Stage** - Builds and tests images:
   - Fetches source code from `Azure-Samples/aks-store-demo` GitHub repository
   - Builds Docker images using Docker Compose
   - Runs health check tests on all services:
     - store-front: http://localhost:8080/health
     - order-service: http://localhost:3000/health
     - product-service: http://localhost:3002/health
   - Stops services after tests pass

2. **Push Stage** - Builds and pushes to ACR (only if tests pass):
   - Builds Docker images for 3 microservices:
     - store-front
     - order-service
     - product-service
   - Pushes images to Azure Container Registry
   - Publishes Helm chart as artifacts for the CD pipeline

### CD Pipeline (`azure-pipelines-cd.yml`)

The CD pipeline performs the following:

1. **Downloads Helm chart** from the CI pipeline artifacts
2. **Updates Helm dependencies** (includes NGINX Ingress Controller)
3. **Deploys to AKS** using HelmDeploy task with:
   - Resource limits for all containers
   - Network policies for inter-service security
   - Security contexts (runAsNonRoot)
   - Health probes (startup, readiness, liveness)
4. **Verifies deployment** health

---

## Project Structure

```
aks-store-demo-solution/
├── azure-pipelines/
│   ├── azure-pipelines-ci.yml    # CI pipeline definition
│   └── azure-pipelines-cd.yml    # CD pipeline definition
├── docker/
│   └── docker-compose.yml        # Local development setup
├── kubernetes/
│   └── helm-chart/               # Helm chart for deployment
│       ├── Chart.yaml            # Chart metadata & dependencies
│       ├── values.yaml           # Default values
│       └── templates/            # Kubernetes templates
├── terraform/
│   └── main.tf                   # Infrastructure as code
└── README.md                     # This file
```

