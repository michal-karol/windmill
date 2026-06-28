# Allow the VM identity to upload DB backups. Scoped to just backups container.
resource "azurerm_role_assignment" "vm_backup_blob" {
  scope                = "/subscriptions/d109d869-87b3-4bf5-b9de-1380f51a8181/resourceGroups/rg-windmill/providers/Microsoft.Storage/storageAccounts/stwindmilltf/blobServices/default/containers/backups"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm_windmill.identity[0].principal_id
}

