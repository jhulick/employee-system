terraform {
  required_providers {
    azurerm = {
      version = "~> 3.116.0"
      source  = "hashicorp/azurerm"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~>1.2.24"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  subscription_id          = data.azurerm_client_config.current.subscription_id
  subscription_resource_id = "/subscriptions/${local.subscription_id}"
  tenant_id                = data.azurerm_client_config.current.tenant_id
}

# ------------------------------------------------------------------------------------------------------
# Deploy app service python app
# ------------------------------------------------------------------------------------------------------
resource "azurecaf_name" "app_name" {
  name          = "${var.service_name}-${var.resource_token}"
  resource_type = "azurerm_app_service"
  random_length = 0
  clean_input   = true
}

resource "azurerm_linux_web_app" "app" {
  name                = azurecaf_name.app_name.result
  location            = var.location
  resource_group_name = var.rg_name
  service_plan_id     = var.appservice_plan_id
  https_only          = true
  tags                = var.tags

  site_config {
    always_on         = var.always_on
    use_32_bit_worker = var.use_32_bit_worker
    ftps_state        = "FtpsOnly"
    app_command_line  = var.app_command_line
    application_stack {
      docker_image_name   = var.docker_image_name
      docker_registry_url = var.docker_registry_url
    }
    health_check_path = var.health_check_path
  }

  app_settings = var.app_settings

  identity {
    type = "SystemAssigned"
  }

  # identity {
  #   type         = "UserAssigned"
  #   identity_ids = [var.user_assigned_identity_id]
  # }

  logs {
    application_logs {
      file_system_level = "Verbose"
    }
    detailed_error_messages = true
    failed_request_tracing  = true
    http_logs {
      file_system {
        retention_in_days = 1
        retention_in_mb   = 35
      }
    }
  }
}

# Grant the system identity AcrPull on your ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# ──────────────────────────────────────────────────────────────────────────────
# Custom RBAC Role Definition – Cosmos DB Data Contributor (limited)
# ──────────────────────────────────────────────────────────────────────────────
# resource "azurerm_role_definition" "cosmos_custom_data_contributor" {
#   name        = "Custom - Cosmos DB Data Contributor"
#   scope       = local.subscription_resource_id
#   description = "Custom role: Full data-plane access to Cosmos DB SQL containers and items, plus read metadata"

#   permissions {
#     data_actions = [
#       "Microsoft.AzureCosmosDB/databaseAccounts/readMetadata",
#       "Microsoft.AzureCosmosDB/databaseAccounts/sqlDatabases/containers/*",
#       "Microsoft.AzureCosmosDB/databaseAccounts/sqlDatabases/containers/items/*"
#     ]

#     not_data_actions = []
#   }

#   assignable_scopes = [
#     local.subscription_resource_id  
#   ]
# }

# resource "azurerm_role_assignment" "cosmos_data_contributor" {
#   scope                = var.cosmos_account_id
#   role_definition_name = "Cosmos DB Built-in Data Contributor"   # ← This is the correct, current name
#   principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
# }

# Optional: Assign the custom role to a principal (e.g. Managed Identity, User, SPN)
# resource "azurerm_role_assignment" "assign_custom_role" {
#   scope              = var.cosmos_account_id   # Cosmos DB account ID
#   role_definition_id = azurerm_role_definition.cosmos_custom_data_contributor.role_definition_resource_id
#   principal_id       = azurerm_linux_web_app.app.identity[0].principal_id   # e.g. managed identity, user, or SPN object ID
# }

# Wait for RBAC propagation (Azure RBAC can take 5–15 min)
# resource "time_sleep" "wait_rbac" {
#   depends_on = [azurerm_role_assignment.cosmos_data_contributor]
#   create_duration = "300s"  # Increase to "300s" if you still get 403 errors
# }

# ------------------------------------------------------------------------------------------------------
# Deploy app service virtual network swift connection
# ------------------------------------------------------------------------------------------------------
resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_linux_web_app.app.id
  subnet_id      = var.subnet_id
}
