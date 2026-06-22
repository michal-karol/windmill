output "public_instance_ip" {
  description = "Public IP for the VM"
  value       = azurerm_public_ip.pip_windmill.ip_address
}

output "private_instance_ip" {
  description = "Private IP for the VM"
  value       = azurerm_linux_virtual_machine.vm_windmill.private_ip_address
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.kv_windmill.vault_uri
}