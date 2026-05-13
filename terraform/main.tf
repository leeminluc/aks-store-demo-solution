module "aks_store" {
  source = "github.com/Azure-Samples/aks-store-demo//infra/terraform?ref=2.1.0"

  environment                     = "demo"
  location                        = "westus2"
  deploy_azure_container_registry = true
  deploy_azure_servicebus         = false
  deploy_observability_tools      = false
  deploy_azure_cosmosdb           = false
  deploy_azure_openai             = false
}
