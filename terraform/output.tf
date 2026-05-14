# =============================================================================
# AKS Store Demo - Terraform Outputs
# =============================================================================

# Resource Group Name
output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.aks_store.AZURE_RESOURCE_GROUP
}

# AKS Cluster Name
output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks_store.AZURE_AKS_CLUSTER_NAME
}

# ACR Login Server
output "acr_login_server" {
  description = "The login server URL of the Azure Container Registry"
  value       = module.aks_store.AZURE_CONTAINER_REGISTRY_ENDPOINT
}

# ACR Name (without .azurecr.io suffix)
output "acr_name" {
  description = "The name of the Azure Container Registry (without .azurecr.io suffix)"
  value       = module.aks_store.AZURE_CONTAINER_REGISTRY_NAME
}
