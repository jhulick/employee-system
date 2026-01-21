output "login_server" {
  description = "The URL that can be used to log in to the container registry."
  value       = azurerm_container_registry.acr.login_server
}

output "admin_username" {
  description = "The admin username of the container registry."
  value       = azurerm_container_registry.acr.admin_username
}

output "admin_password" {
  description = "The admin password of the container registry."
  value       = azurerm_container_registry.acr.admin_password
}

output "container_registry_id" {
  description = "The resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.acr.id 
}

