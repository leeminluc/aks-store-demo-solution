# AKS Store Demo - DevOps Challenge Solution

This repository contains a complete solution for deploying the AKS Store Demo application on Azure Kubernetes Service (AKS) using Infrastructure as Code (Terraform), containerization (Docker), and CI/CD automation (Azure DevOps).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Running Locally](#running-locally)
- [Infrastructure Deployment](#infrastructure-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Helm Chart Deployment (Bonus)](#helm-chart-deployment-bonus)
- [Cleanup](#cleanup)

## Prerequisites

### Required Tools

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.50+)
- [Terraform](https://www.terraform.io/downloads) (v1.5+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.28+)
- [Helm](https://helm.sh/docs/intro/install/) (v3.12+)
- [Docker](https://www.docker.com/get-started) (v24+)
- [Git](https://git-scm.com/downloads)

### Azure Requirements

- Azure Subscription with Contributor access
- Azure DevOps organization and project
- Service Principal for CI/CD pipeline

### Setup Azure CLI

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<subscription-id>"

# Verify current subscription
az account show
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Resource Group                          │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │  │
│  │  │     ACR     │  │     AKS     │  │ Log Analytics    │   │  │
│  │  │  Container  │  │  Kubernetes │  │    Workspace     │   │  │
│  │  │  Registry   │  │   Cluster   │  │                  │   │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────────────────┘   │  │
│  │         │                │                                 │  │
│  │         └────────────────┘                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Application Components

| Service | Description | Port |
|---------|-------------|------|
| store-front | Web frontend (Vue.js) | 8080 |
| store-admin | Admin dashboard (Vue.js) | 8081 |
| order-service | Order processing (Node.js) | 3000 |
| product-service | Product catalog (Rust) | 3002 |
| makeline-service | Order queue processor (Go) | 3001 |
| ai-service | AI recommendations (Python) | 5001 |
| rabbitmq | Message queue | 5672 |
| mongodb | Order storage | 27017 |

## Running Locally

### Using Docker Compose

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd aks-store-demo-solution
   ```

2. **Start all services:**
   ```bash
   cd docker
   docker-compose up -d
   ```

3. **Access the application:**
   - Store Front: http://localhost:8080
   - Store Admin: http://localhost:8081
   - RabbitMQ Management: http://localhost:15672 (guest/guest)

4. **Stop all services:**
   ```bash
   docker-compose down
   ```

### Using Kubernetes (Local - minikube/kind)

1. **Start local cluster:**
   ```bash
   # Using minikube
   minikube start
   
   # Or using kind
   kind create cluster
   ```

2. **Deploy the application:**
   ```bash
   kubectl apply -f kubernetes/manifests/aks-store-quickstart.yaml
   ```

3. **Access the application:**
   ```bash
   kubectl port-forward svc/store-front 8080:80
   ```

## Infrastructure Deployment

### Terraform Configuration

This solution uses the existing Terraform code from the [aks-store-demo repository](https://github.com/Azure-Samples/aks-store-demo). The Terraform code is located in `aks-store-demo/infra/terraform/` and uses Azure Verified Modules (AVM) for best practices.

The Terraform configuration creates:
- Azure Resource Group
- Azure Kubernetes Service (AKS) cluster
- Azure Container Registry (ACR)
- Required role assignments (ACR pull access for AKS)

### Deploy Infrastructure

1. **Navigate to the demo repository's Terraform directory:**
   ```bash
   cd ~/challenge/aks-store-demo/infra/terraform
   ```

2. **Copy the terraform.tfvars from this solution:**
   ```bash
   cp ~/challenge/aks-store-demo-solution/terraform/terraform.tfvars .
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan -out main.tfplan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply main.tfplan
   ```

6. **Get AKS credentials:**
   ```bash
   # Get the resource group and cluster name from outputs
   terraform output
   
   # Get AKS credentials
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
   ```

### Terraform Variables

The `terraform.tfvars` file in this solution configures a minimal deployment:

| Variable | Description | Value |
|----------|-------------|-------|
| location | Azure region | eastus |
| environment | Environment name | dev |
| aks_node_pool_vm_size | VM size for nodes | Standard_D2s_v4 |
| k8s_namespace | Kubernetes namespace | store-demo |
| deploy_azure_container_registry | Create ACR | true |
| deploy_observability_tools | Deploy monitoring | false |
| deploy_azure_servicebus | Use Azure Service Bus | false |
| deploy_azure_cosmosdb | Use Azure CosmosDB | false |
| deploy_azure_openai | Deploy Azure OpenAI | false |

## CI/CD Pipeline

### Azure DevOps Setup

1. **Create Azure DevOps Project:**
   - Go to https://dev.azure.com
   - Create a new project named "aks-store-demo"

2. **Create Service Connection:**
   - Go to Project Settings > Service connections
   - Create "Azure Resource Manager" connection
   - Select "Service principal (automatic)"
   - Name it "azure-subscription"

3. **Create Variable Group:**
   - Go to Pipelines > Library
   - Create variable group "aks-store-demo-variables"
   - Add variables:
     - `azureSubscription`: Your subscription ID
     - `resourceGroup`: rg-aks-store-demo
     - `aksCluster`: aks-store-demo
     - `acrName`: acrstoredemo
     - `containerRegistry`: acrstoredemo.azurecr.io

4. **Import Pipeline:**
   - Go to Pipelines > Create Pipeline
   - Select "Azure Repos Git"
   - Select "Existing Azure Pipelines YAML file"
   - Select `/azure-pipelines/azure-pipelines-ci.yml`

### Pipeline Stages

#### CI Pipeline (azure-pipelines-ci.yml)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Build     │───▶│    Test     │───▶│   Docker    │───▶│    Push     │
│             │    │             │    │   Build     │    │    to ACR   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**Stages:**
1. **Build**: Compile all services
2. **Test**: Run unit and integration tests
3. **Docker Build**: Build container images
4. **Push to ACR**: Push images to Azure Container Registry

#### CD Pipeline (azure-pipelines-cd.yml)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Deploy    │───▶│   Verify    │───▶│   Notify    │
│   to AKS    │    │   Health    │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
```

**Stages:**
1. **Deploy to AKS**: Apply Kubernetes manifests
2. **Verify Health**: Check deployment status
3. **Notify**: Send deployment notifications

### Running Pipelines

1. **Trigger CI Pipeline:**
   - Push changes to main branch
   - Or manually trigger from Azure DevOps

2. **Trigger CD Pipeline:**
   - Automatically after successful CI
   - Or manually with approval gates

## Kubernetes Deployment

### Manual Deployment

1. **Create namespace:**
   ```bash
   kubectl create namespace store-demo
   ```

2. **Deploy NGINX Ingress Controller:**
   ```bash
   kubectl apply -f kubernetes/manifests/ingress-controller.yaml
   ```

3. **Deploy the application:**
   ```bash
   kubectl apply -f kubernetes/manifests/aks-store-quickstart.yaml -n store-demo
   ```

4. **Deploy Ingress:**
   ```bash
   kubectl apply -f kubernetes/manifests/ingress.yaml -n store-demo
   ```

5. **Get Ingress IP:**
   ```bash
   kubectl get ingress -n store-demo
   ```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n store-demo

# Check services
kubectl get services -n store-demo

# Check ingress
kubectl get ingress -n store-demo

# View logs
kubectl logs -f deployment/store-front -n store-demo
```

## Helm Chart Deployment (Bonus)

### Install with Helm

1. **Navigate to Helm chart:**
   ```bash
   cd kubernetes/helm-chart
   ```

2. **Update dependencies:**
   ```bash
   helm dependency update
   ```

3. **Install the chart:**
   ```bash
   helm install aks-store-demo . -n store-demo --create-namespace
   ```

4. **Upgrade with custom values:**
   ```bash
   helm upgrade aks-store-demo . -n store-demo -f values-prod.yaml
   ```

### Helm Chart Features

- **Resource Limits**: Configured CPU and memory limits for all services
- **Network Policies**: Restrict inter-service communication
- **Horizontal Pod Autoscaler**: Auto-scaling support
- **Ingress**: Configurable ingress with TLS support
- **Security Contexts**: Non-root containers, read-only filesystems

### Custom Values

Create a custom values file:

```yaml
# values-custom.yaml
replicaCount: 2

namespace: production

storeFront:
  image:
    repository: acrstoredemo.azurecr.io/store-front
    tag: "latest"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: store.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: store-tls
      hosts:
        - store.example.com
```

## Cleanup

### Delete Kubernetes Resources

```bash
kubectl delete namespace store-demo
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

### Delete Azure Resources

```bash
az group delete --name rg-aks-store-demo --yes --no-wait
```

## Troubleshooting

### Common Issues

1. **Image Pull Errors:**
   ```bash
   # Check ACR credentials
   kubectl create secret docker-registry acr-secret \
     --docker-server=acrstoredemo.azurecr.io \
     --docker-username=<username> \
     --docker-password=<password>
   ```

2. **Ingress Not Working:**
   ```bash
   # Check ingress controller logs
   kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
   ```

3. **Pod Stuck in Pending:**
   ```bash
   # Describe pod for events
   kubectl describe pod <pod-name> -n store-demo
   ```

## Project Structure

```
aks-store-demo-solution/
├── README.md                          # This file
├── kubernetes/
│   ├── manifests/
│   │   ├── aks-store-quickstart.yaml   # Main application manifest
│   │   ├── ingress-controller.yaml     # NGINX Ingress Controller
│   │   └── ingress.yaml                # Ingress resource definitions
│   └── helm-chart/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── kubernetes.tf
│   ├── acr.tf
│   └── terraform.tfvars
├── azure-pipelines/
│   ├── azure-pipelines-ci.yml         # CI pipeline
│   └── azure-pipelines-cd.yml         # CD pipeline
└── docker/
    └── docker-compose.yml              # Local development
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Original [AKS Store Demo](https://github.com/Azure-Samples/aks-store-demo) repository
- Azure Kubernetes Service documentation
- Terraform Azure Provider documentation