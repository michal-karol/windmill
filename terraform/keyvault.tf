resource "azurerm_key_vault" "kv_windmill" {
  name                          = "kv-windmill"
  location                      = local.location
  resource_group_name           = azurerm_resource_group.rg_windmill.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true # need to be true becouse github actions use public runners, if using self-hosted ones then can be false - TBC 
  enable_rbac_authorization     = true # need to rename to rbac_authorization_enabled = true = true, once azure provider is v 5.0
  sku_name                      = "standard"
  tags                          = local.common_tags
}

resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "db_pass" {
  name         = "db-pass"
  content_type = "text/plain"
  value        = random_password.postgres_password.result
  key_vault_id = azurerm_key_vault.kv_windmill.id
  tags         = local.common_tags
}

resource "azurerm_role_assignment" "kv_secrets_officer_tf" {
  scope                = azurerm_key_vault.kv_windmill.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_secrets_user_vm" {
  scope                = azurerm_key_vault.kv_windmill.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.vm_windmill.identity[0].principal_id
}