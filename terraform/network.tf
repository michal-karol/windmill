# Create a network security group, virtual network and subnet
resource "azurerm_network_security_group" "nsg_windmill" {
  name                = "nsg-windmill"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_windmill.name

  security_rule {
    name                       = "Allow_443_access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.allowed_source_ip
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_virtual_network" "vnet_windmill" {
  name                = "vnet-windmill"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_windmill.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "snet_windmill" {
  name                 = "snet-windmill"
  resource_group_name  = azurerm_resource_group.rg_windmill.name
  virtual_network_name = azurerm_virtual_network.vnet_windmill.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "snet_nsg_windmill" {
  subnet_id                 = azurerm_subnet.snet_windmill.id
  network_security_group_id = azurerm_network_security_group.nsg_windmill.id
}

resource "azurerm_public_ip" "pip_windmill" {
  name                = "pip-windmill"
  resource_group_name = azurerm_resource_group.rg_windmill.name
  location            = local.location
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "windmill-slotwinski"
  tags                = local.common_tags
}