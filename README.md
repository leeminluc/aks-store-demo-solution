# AKS Store Demo Solution

This repository contains the CI/CD pipelines and infrastructure code for deploying the AKS Store Demo application to Azure Kubernetes Service (AKS).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deploy to AKS with CI/CD Pipeline](#deploy-to-aks-with-cicd-pipeline)
- [Run Locally with Docker Compose](#run-locally-with-docker-compose)
- [Project Structure](#project-structure)

---

## Prerequisites

### For CI/CD Pipeline Deployment

| Requirement | Description |
|-------------|-------------|
| Azure Subscription | With Owner or Contributor access |
| Azure DevOps Organization | Create at [dev.azure.com](https://dev.azure.com) |
| Azure DevOps Project | Create a new project for this solution |
| Terraform | >= 1.0 (for infrastructure setup) |
| Azure CLI | Authenticated with `az login` |

### For Running Locally

| Tool | Version | Description |
|------|---------|-------------|
| Docker | 20.x+ | Container runtime |
| Docker Compose | 2.x+ | Multi-container orchestration |

---

## Deploy to AKS with CI/CD Pipeline

### Step 1: Create Azure Infrastructure with Terraform

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

5. **Note the output values** - You'll need these for the CI/CD configuration:
   - `resource_group_name` - Resource group name
   - `aks_cluster_name` - AKS cluster name
   - `acr_login_server` - ACR login server URL
   - `acr_name` - ACR name (without .azurecr.io)

6. **Get AKS credentials:**
   ```bash
   az aks get-credentials \
     --resource-group <resource-group-name> \
     --name <aks-cluster-name>
   ```

---

### Step 2: Configure Azure DevOps

#### 2.1 Create Service Connections

Navigate to **Project Settings > Service connections** and create the following:

**GitHub Connection:**

| Field | Value |
|-------|-------|
| Connection type | GitHub |
| Connection name | `github-connection` |
| Authentication | OAuth or Personal Access Token |

**Azure Container Registry Connection:**

| Field | Value |
|-------|-------|
| Connection type | Docker Registry |
| Connection name | `acr-connection` |
| Registry type | Azure Container Registry |
| Azure subscription | Your subscription |
| Azure Container Registry | Your ACR instance |

**Azure Resource Manager Connection:**

| Field | Value |
|-------|-------|
| Connection type | Azure Resource Manager |
| Connection name | `azure-connection` |
| Authentication method | Service principal (automatic) |
| Scope level | Subscription |
| Subscription | Your subscription |

#### 2.2 Create Variable Group

Navigate to **Pipelines > Library** and create a variable group named `aks-store-demo-variables`:

| Variable Name | Example Value | Description |
|---------------|---------------|-------------|
| `containerRegistryName` | `acrdemoguppy53` | ACR name (without .azurecr.io) |
| `containerRegistry` | `acrdemoguppy53.azurecr.io` | Full ACR login server URL |
| `resourceGroup` | `rg-demoguppy53` | Resource group name |
| `aksCluster` | `aks-demoguppy53` | AKS cluster name |

---

### Step 3: Import Pipelines

#### 3.1 Import CI Pipeline (Build Images)

1. Go to **Pipelines > Create Pipeline**
2. Select **Azure Repos Git** (or your Git provider)
3. Select your repository
4. Select **Existing Azure Pipelines YAML file**
5. Select the path: `/azure-pipelines/azure-pipelines-ci-images.yml`
6. Save the pipeline as `aks-store-demo-ci-images`

#### 3.2 Import CI Pipeline (Package Helm)

1. Go to **Pipelines > Create Pipeline**
2. Select **Azure Repos Git** (or your Git provider)
3. Select your repository
4. Select **Existing Azure Pipelines YAML file**
5. Select the path: `/azure-pipelines/azure-pipelines-ci-helm.yml`
6. Save the pipeline as `aks-store-demo-ci-helm`

#### 3.3 Import CD Pipeline

1. Go to **Pipelines > Create Pipeline**
2. Select **Azure Repos Git** (or your Git provider)
3. Select your repository
4. Select **Existing Azure Pipelines YAML file**
5. Select the path: `/azure-pipelines/azure-pipelines-cd.yml`
6. Save the pipeline as `aks-store-demo-cd`

---

### Step 4: Configure AKS for CI/CD

After the AKS cluster is created, run these commands to enable the CD pipeline to deploy:

**4.1 Disable Authorized IP Ranges:**
```bash
az aks update \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name> \
  --api-server-authorized-ip-ranges ""
```

**4.2 Get the Service Principal Object ID:**

Go to **Azure Portal > Azure Active Directory > Enterprise applications** and search for the service principal name (same as your Azure DevOps project name). Copy the Object ID.

**4.3 Create Role Assignment:**
```bash
az role assignment create \
  --assignee <service-principal-object-id> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.ContainerService/managedClusters/<aks-cluster-name>
```

**4.4 Create ClusterRoleBinding:**
```bash
kubectl create clusterrolebinding azure-devops-admin-binding \
  --clusterrole=cluster-admin \
  --user=<service-principal-object-id>
```

---

### Step 5: Run the Pipelines

Run the pipelines in this order:

**5.1 Run CI Pipeline (Build Images):**
1. Go to Pipelines
2. Select `aks-store-demo-ci-images`
3. Click **Run pipeline**
4. This builds and pushes Docker images to ACR

**5.2 Run CI Pipeline (Package Helm):**
1. Go to Pipelines
2. Select `aks-store-demo-ci-helm`
3. Click **Run pipeline**
4. This packages and publishes the Helm chart

**5.3 Run CD Pipeline:**
1. Go to Pipelines
2. Select `aks-store-demo-cd`
3. Click **Run pipeline**
4. This installs NGINX Ingress Controller and deploys the application

---

### Step 6: Access the Application

1. **Get the Ingress Controller external IP:**
   ```bash
   kubectl get svc -n ingress-nginx
   ```

2. **Access the application:**
   Open a browser and navigate to `http://<EXTERNAL-IP>`

---

## Run Locally with Docker Compose

The application can be run locally using Docker Compose. This pulls images from your Azure Container Registry (ACR) - the same images built by the CI pipeline.

### Prerequisites

- CI pipeline must have run successfully to push images to ACR
- Azure CLI installed and authenticated

### Steps

1. **Login to Azure Container Registry:**
   ```bash
   az acr login --name <acr-name>
   ```
   Example:
   ```bash
   az acr login --name acrdemoguppy53
   ```

2. **Set environment variables:**
   ```bash
   export ACR_REGISTRY=<acr-name>.azurecr.io
   export IMAGE_TAG=latest
   ```
   Example:
   ```bash
   export ACR_REGISTRY=acrdemoguppy53.azurecr.io
   export IMAGE_TAG=latest
   ```

3. **Navigate to the docker directory:**
   ```bash
   cd docker
   ```

4. **Start all services:**
   ```bash
   docker-compose up -d
   ```

5. **Verify services are running:**
   ```bash
   docker-compose ps
   ```

6. **Access the application:**
   - **Store Front:** http://localhost:8080
   - **RabbitMQ Management:** http://localhost:15672 (username: `username`, password: `password`)

7. **Stop all services:**
   ```bash
   docker-compose down
   ```

---

## Project Structure

```
aks-store-demo-solution/
├── azure-pipelines/
│   ├── azure-pipelines-ci-images.yml  # CI pipeline for building images
│   ├── azure-pipelines-ci-helm.yml     # CI pipeline for packaging Helm
│   └── azure-pipelines-cd.yml          # CD pipeline for deployment
├── docker/
│   └── docker-compose.yml              # Local development setup
├── kubernetes/
│   └── helm-chart/                     # Helm chart for deployment
│       ├── Chart.yaml                  # Chart metadata
│       ├── values.yaml                  # Default values
│       └── templates/                  # Kubernetes templates
│           ├── store-front-deployment.yaml
│           ├── store-front-service.yaml
│           ├── order-service-deployment.yaml
│           ├── order-service-service.yaml
│           ├── product-service-deployment.yaml
│           ├── product-service-service.yaml
│           ├── rabbitmq.yaml
│           ├── ingress.yaml
│           └── networkpolicy.yaml
├── terraform/
│   └── main.tf                         # Infrastructure as code
└── README.md                           # This file
```

---

## Features Deployed

- **Resource Limits** - CPU and memory limits for all containers
- **Network Policies** - Inter-service security policies
- **Health Probes** - Startup, readiness, and liveness probes
- **NGINX Ingress Controller** - External access via Load Balancer
- **RabbitMQ** - Message queue for order processing
