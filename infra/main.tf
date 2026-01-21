locals {
  tags                         = { azd-env-name : var.environment_name }
  sha                          = base64encode(sha256("${var.environment_name}${var.location}${data.azurerm_client_config.current.subscription_id}"))
  resource_token               = substr(replace(lower(local.sha), "[^A-Za-z0-9_]", ""), 0, 13)
  api_command_line             = "gunicorn --workers 4 --threads 2 --timeout 60 --access-logfile \"-\" --error-logfile \"-\" --bind=0.0.0.0:8000 -k uvicorn.workers.UvicornWorker todo.app:app"
  cosmos_connection_string_key = "AZURE-COSMOS-CONNECTION-STRING"
}

# ------------------------------------------------------------------------------------------------------
# Deploy resource Group
# ------------------------------------------------------------------------------------------------------
resource "azurecaf_name" "rg_name" {
  name          = var.environment_name
  resource_type = "azurerm_resource_group"
  random_length = 0
  clean_input   = true
}

resource "azurerm_resource_group" "rg" {
  name     = azurecaf_name.rg_name.result
  location = var.location

  tags = local.tags
}

# ------------------------------------------------------------------------------------------------------
# User-Assinged Managed Identity (shared)
# ------------------------------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "restaurant-app-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# ------------------------------------------------------------------------------------------------------
# Deploy Vnet and Subnets
# ------------------------------------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "restaurant-rec-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "app_service_subnet" {
  name                 = "app-service-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }

}

resource "azurerm_subnet" "cosmos_subnet" {
  name                 = "cosmos-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.AzureCosmosDB"]
}

resource "azurerm_subnet" "keyvault_subnet" {
  name                 = "keyvault-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.KeyVault"]
}

# ------------------------------------------------------------------------------------------------------
# Deploy application insights
# ------------------------------------------------------------------------------------------------------
module "applicationinsights" {
  source           = "./modules/applicationinsights"
  location         = var.location
  rg_name          = azurerm_resource_group.rg.name
  environment_name = var.environment_name
  workspace_id     = module.loganalytics.LOGANALYTICS_WORKSPACE_ID
  tags             = azurerm_resource_group.rg.tags
  resource_token   = local.resource_token
}

# ------------------------------------------------------------------------------------------------------
# Deploy log analytics
# ------------------------------------------------------------------------------------------------------
module "loganalytics" {
  source         = "./modules/loganalytics"
  location       = var.location
  rg_name        = azurerm_resource_group.rg.name
  tags           = azurerm_resource_group.rg.tags
  resource_token = local.resource_token
}

# ------------------------------------------------------------------------------------------------------
# Deploy key vault
# ------------------------------------------------------------------------------------------------------
module "keyvault" {
  source         = "./modules/keyvault"
  location       = var.location
  principal_id   = azurerm_user_assigned_identity.app_identity.principal_id
  rg_name        = azurerm_resource_group.rg.name
  tags           = azurerm_resource_group.rg.tags
  resource_token = local.resource_token
  subnet_id      = azurerm_subnet.keyvault_subnet.id
  subnets        = [azurerm_subnet.keyvault_subnet.id]
  secrets = [
    {
      name  = local.cosmos_connection_string_key
      value = module.cosmos.AZURE_COSMOS_CONNECTION_STRING
    }
  ]
}

# ------------------------------------------------------------------------------------------------------
# Deploy cosmos db with private endpoint
# ------------------------------------------------------------------------------------------------------
module "cosmos" {
  source                    = "./modules/cosmos"
  location                  = var.location
  rg_name                   = azurerm_resource_group.rg.name
  tags                      = azurerm_resource_group.rg.tags
  resource_token            = local.resource_token
  vnet_id                   = azurerm_virtual_network.main.id
  subnet_id                 = azurerm_subnet.cosmos_subnet.id
  app_service_subnet_prefix = azurerm_subnet.app_service_subnet.address_prefixes[0]
}

# Grant the identity access to Cosmos DB (data plane)
resource "azurerm_role_assignment" "cosmos_data_contributor" {
  scope                = module.cosmos.account_id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# small delay to let RBAC propagate
resource "time_sleep" "wait_30_seconds" {
  depends_on      = [azurerm_role_assignment.cosmos_data_contributor]
  create_duration = "30s"
}

# ------------------------------------------------------------------------------------------------------
# Deploy container registry
# ------------------------------------------------------------------------------------------------------
module "containerregistry" {
  source         = "./modules/containerregistry"
  location       = var.location
  rg_name        = azurerm_resource_group.rg.name
  resource_token = local.resource_token
  key_vault_id   = module.keyvault.AZURE_KEY_VAULT_ID
  registry_name  = var.registry_name
}


# ------------------------------------------------------------------------------------------------------
# Deploy app service plan
# ------------------------------------------------------------------------------------------------------
module "appserviceplan" {
  source         = "./modules/appserviceplan"
  location       = var.location
  rg_name        = azurerm_resource_group.rg.name
  tags           = local.tags
  resource_token = local.resource_token
  sku_name       = "B3"
}

# ------------------------------------------------------------------------------------------------------
# Deploy app service api
# ------------------------------------------------------------------------------------------------------
module "appservicepython" {
  source                    = "./modules/appservicepython"
  location                  = var.location
  rg_name                   = azurerm_resource_group.rg.name
  resource_token            = local.resource_token
  subnet_id                 = azurerm_subnet.app_service_subnet.id
  docker_image_name         = var.docker_image_name
  docker_registry_url       = var.docker_registry_url
  user_assigned_identity_id = azurerm_user_assigned_identity.app_identity.id

  cosmos_account_id = module.cosmos.account_id
  container_registry_id = module.containerregistry.container_registry_id

  tags               = merge(local.tags, { "service-name" : "api" })
  service_name       = "api"
  appservice_plan_id = module.appserviceplan.APPSERVICE_PLAN_ID
  app_settings = {
    "AZURE_COSMOS_CONNECTION_STRING_KEY"    = local.cosmos_connection_string_key
    "AZURE_COSMOS_DATABASE_NAME"            = module.cosmos.AZURE_COSMOS_DATABASE_NAME
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    "DOCKER_ENABLE_CI"                      = "true"
    "AZURE_KEY_VAULT_ENDPOINT"              = module.keyvault.AZURE_KEY_VAULT_ENDPOINT
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.applicationinsights.APPLICATIONINSIGHTS_CONNECTION_STRING
  }

  app_command_line = local.api_command_line
}

