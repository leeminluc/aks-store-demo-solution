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

The Docker Compose setup pulls images from your Azure Container Registry (ACR). This allows you to test the same images that are deployed to AKS.

### Prerequisites

- Docker images must be built and pushed to ACR (run the CI pipeline first)
- Azure CLI installed and authenticated

### Steps to Run

1. **Login to Azure Container Registry:**
   ```bash
   az acr login --name <acr-name>
   ```
   Example:
   ```bash
   az acr login --name acrdemozebra95
   ```

2. **Set environment variables:**
   ```bash
   export ACR_REGISTRY=<acr-name>.azurecr.io
   export IMAGE_TAG=latest
   ```
   Example:
   ```bash
   export ACR_REGISTRY=acrdemozebra95.azurecr.io
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

### Troubleshooting

If you get an authentication error, ensure you're logged in to ACR:
```bash
az acr login --name <acr-name>
```

If images are not found, ensure the CI pipeline has completed and pushed images to ACR.

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
   - Manually run it from the Pipelines page


---

## Post-Deployment Configuration

After the AKS cluster is created, additional configuration is required for the CD pipeline to work properly.

### 1. Disable Authorized IP Ranges (if enabled)

If the AKS cluster has authorized IP ranges enabled, the CD pipeline service principal won't be able to connect. Disable it:

```bash
az aks update \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name> \
  --api-server-authorized-ip-ranges ""
```

Example:
```bash
az aks update \
  --resource-group rg-demoguppy53 \
  --name aks-demoguppy53 \
  --api-server-authorized-ip-ranges ""
```

### 2. Create Role Assignment for CD Pipeline

The CD pipeline service principal needs Contributor access to the AKS cluster:

```bash
az role assignment create \
  --assignee <service-principal-object-id> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.ContainerService/managedClusters/<aks-cluster-name>
```

Example:
```bash
az role assignment create \
  --assignee 287399e2-6e00-4269-a0ee-1462f484b37e \
  --role "Contributor" \
  --scope /subscriptions/34f3d6fb-aee3-4f71-a39e-35b2914052a0/resourceGroups/rg-demoguppy53/providers/Microsoft.ContainerService/managedClusters/aks-demoguppy53
```

### 3. Create ClusterRoleBinding for Kubernetes RBAC

The CD pipeline service principal needs cluster-admin rights to deploy resources and access secrets:

```bash
kubectl create clusterrolebinding azure-devops-admin-binding \
  --clusterrole=cluster-admin \
  --user=<service-principal-object-id>
```

Example:
```bash
kubectl create clusterrolebinding azure-devops-admin-binding \
  --clusterrole=cluster-admin \
  --user=287399e2-6e00-4269-a0ee-1462f484b37e
```

> **Note:** Replace `<service-principal-object-id>` with the Object ID of the service principal used by your Azure DevOps service connection. You can find this in the Azure Portal under **Azure Active Directory > Enterprise applications**.

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

