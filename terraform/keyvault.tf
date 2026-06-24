resource "azurerm_key_vault" "kv_windmill" {
  #checkov:skip=CKV_AZURE_189:GitHub-hosted runners require public access.
  #checkov:skip=CKV_AZURE_109:GitHub-hosted runners require public access; network ACLs would block CI pipeline
  #checkov:skip=CKV_AZURE_110:Personal dev subscription; purge protection disabled to allow clean teardown
  #checkov:skip=CKV_AZURE_42:Personal dev subscription; soft delete 7 days retained, purge protection intentionally off
  #checkov:skip=CKV2_AZURE_32:No private endpoint; GitHub-hosted runners require public network access
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
  override_special = "!#$*()-_=+[]{}<>:?"
}

# TODO PR 2: replace expiration_date with rotation_policy block
# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret#rotation_policy
resource "azurerm_key_vault_secret" "db_pass" {
  name            = "db-pass"
  content_type    = "text/plain"
  value           = random_password.postgres_password.result
  key_vault_id    = azurerm_key_vault.kv_windmill.id
  expiration_date = "2027-06-24T00:00:00Z"
  tags            = local.common_tags
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