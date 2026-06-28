resource "tls_private_key" "vm_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "azurerm_linux_virtual_machine" "vm_windmill" {
  name                       = "vm-windmill"
  resource_group_name        = azurerm_resource_group.rg_windmill.name
  location                   = local.location
  allow_extension_operations = false
  size                       = "Standard_B2s"
  admin_username             = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic_windmill_vm.id
  ]

  admin_ssh_key {
    username = "adminuser"
    # TEMP debug: use an externally-held keypair (private key off-state) so we can
    # SSH in to diagnose the 502. Revert to tls_private_key.vm_ssh_key once done.
    public_key = file("${path.module}/files/vm_ssh_key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "server"
    # Pinned for reproducibility (was "latest", which can silently force VM
    # replacement when Canonical publishes a new image). Bump deliberately; check
    # newer with: az vm image list -l denmarkeast -p Canonical -f ubuntu-26_04-lts \
    #   --sku server --all --query "[?sku=='server'].version" -o tsv | sort -V | tail
    version = "26.04.202606210"
  }

  disable_password_authentication = true

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {}

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
    docker_compose_b64 = base64encode(file("${path.module}/files/docker-compose.yml"))
    caddyfile_b64      = base64encode(file("${path.module}/files/Caddyfile"))
    env_b64 = base64encode(templatefile("${path.module}/files/.env.tpl", {
      base_url = azurerm_public_ip.pip_windmill.fqdn
    }))
    vault_name  = azurerm_key_vault.kv_windmill.name
    secret_name = azurerm_key_vault_secret.db_pass.name
  }))

  tags = local.common_tags
}