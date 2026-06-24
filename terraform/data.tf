# This reads the details of whoever is currently authenticated to Azure, at runtime, not hardcoded.
data "azurerm_client_config" "current" {}