# Create a resource group
resource "azurerm_resource_group" "rg_windmill" {
  name     = "rg-windmill"
  location = local.rg_location
  tags     = local.common_tags
}

import {
  to = azurerm_resource_group.rg_windmill
  id = "/subscriptions/d109d869-87b3-4bf5-b9de-1380f51a8181/resourceGroups/rg-windmill"
}