output "AZURE_COSMOS_CONNECTION_STRING" {
  value     = azurerm_cosmosdb_account.db.connection_strings[0]
  sensitive = true
}

output "AZURE_COSMOS_DATABASE_NAME" {
  value = azurerm_cosmosdb_mongo_database.mongodb.name
}

output "endpoint" {
  value = azurerm_cosmosdb_account.db.endpoint
}

output "account_id" {
  value = azurerm_cosmosdb_account.db.id
}
