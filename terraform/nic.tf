resource "azurerm_network_interface" "nic_windmill_vm" {
  name                = "nic-windmill-vm"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_windmill.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_windmill.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.pip_windmill.id
  }

  tags = local.common_tags
}