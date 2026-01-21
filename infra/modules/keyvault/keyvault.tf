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

# ------------------------------------------------------------------------------------------------------
# Deploy Azure Key Vault
# ------------------------------------------------------------------------------------------------------
resource "azurecaf_name" "kv_name" {
  name          = var.resource_token
  resource_type = "azurerm_key_vault"
  random_length = 0
  clean_input   = true
}

resource "azurerm_key_vault" "kv" {
  name                        = azurecaf_name.kv_name.result
  location                    = var.location
  resource_group_name         = var.rg_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  enable_rbac_authorization   = true

  tags = var.tags

  network_acls {
    default_action             = "Allow"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.subnets
  }

  # ip_rules = [
  #   "57.154.182.51"   # cloud shell ip
  # ]
}

#------------------------------------------------------------------------------------------------------
# Assign the minimal role: Key Vault Secrets User
#------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "spn_read_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer" #"Key Vault Crypto User"
  principal_id         = var.principal_id
  depends_on = [
    azurerm_key_vault.kv
  ]
}

# ------------------------------------------------------------------------------------------------------
# Deploy secrets to Key Vault
# ------------------------------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "secrets" {
  count        = length(var.secrets)
  name         = var.secrets[count.index].name
  value        = var.secrets[count.index].value
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault.kv
  ]
}

# ------------------------------------------------------------------------------------------------------
# Deploy encryption key to Key Vault
# ------------------------------------------------------------------------------------------------------
resource "azurecaf_name" "key_name" {
  name          = "${var.resource_token}-key"
  resource_type = "azurerm_key_vault_key"
  random_length = 0
  clean_input   = true
}

resource "azurerm_key_vault_key" "encryption_key" {
  name         = azurecaf_name.key_name.result
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  depends_on = [
    azurerm_key_vault.kv
  ]
}
