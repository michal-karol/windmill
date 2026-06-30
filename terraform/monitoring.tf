# Manages a Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log_windmill" {
  name                = "log-windmill"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_windmill.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1

  tags = local.common_tags
}


#Azure monitoring agent extension
resource "azurerm_virtual_machine_extension" "ama_vm_windmill" {
  name                       = "ama-vm-windmill"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm_windmill.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.42" # 2 below settings will updated this handler, its basically starting point.
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  tags = local.common_tags
}


# Manages a Data Collection Rules
resource "azurerm_monitor_data_collection_rule" "dcr_windmill" {
  name                = "dcr-windmill"
  resource_group_name = azurerm_resource_group.rg_windmill.name
  location            = local.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_windmill.id
      name                  = "destination-log-windmill"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["destination-log-windmill"]
  }

  data_sources {
    syslog {
      facility_names = ["*"]
      log_levels     = ["Warning"]
      name           = "datasource-syslog-windmill"
      streams        = ["Microsoft-Syslog"]
    }

    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(*)\\% Processor Time",
        "\\Memory(*)\\Available MBytes Memory",
        "\\Memory(*)\\% Used Memory",
        "\\Logical Disk(*)\\% Free Space",
        "\\Logical Disk(*)\\Free Megabytes",
      ]
      name = "datasource-perfcounter-windmill"
    }

  }

  description = "Collects perf counters and warning+ syslog from vm-windmill"
  tags        = local.common_tags
}


# Associate to a Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "dcra_windmill" {
  name                    = "dcra-windmill"
  target_resource_id      = azurerm_linux_virtual_machine.vm_windmill.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_windmill.id
}