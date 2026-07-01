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


# Manages an Action Group within Azure Monitor.
resource "azurerm_monitor_action_group" "ag_windmill" {
  name                = "ag-windmill"
  resource_group_name = azurerm_resource_group.rg_windmill.name
  short_name          = "p0-windmill"

  email_receiver {
    name          = "send-alert-to-email-windmill"
    email_address = var.alert_email
  }

  webhook_receiver {
    name                    = "send-alert-to-teams-windmill"
    service_uri             = var.teams_webhook_url
    use_common_alert_schema = true
  }

  tags = local.common_tags
}


#Manages a Metric Alert within Azure Monitor.
resource "azurerm_monitor_metric_alert" "alert_high_cpu_windmill" {
  name                = "alert-high-cpu-windmill"
  resource_group_name = azurerm_resource_group.rg_windmill.name
  scopes              = [azurerm_linux_virtual_machine.vm_windmill.id]
  severity            = "1"
  frequency           = "PT5M"  # checks every 5 mins 
  window_size         = "PT15M" # each check look back 15 mins 
  description         = "Action will be triggered when CPU utilsiation is greater than 80%."

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag_windmill.id
  }

  tags = local.common_tags
}

# Manages a Scheduled Query Rule (log alert) - low available memory
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "alert_low_memory_windmill" {
  name                    = "alert-low-memory-windmill"
  resource_group_name     = azurerm_resource_group.rg_windmill.name
  location                = local.location
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  scopes                  = [azurerm_log_analytics_workspace.log_windmill.id]
  severity                = 1
  description             = "Fires when average available memory drops below 300MB"
  display_name            = "alert-low-memory-windmill"
  enabled                 = true
  auto_mitigation_enabled = true

  criteria {
    query = <<-QUERY
      Perf
      | where CounterName == "Available MBytes Memory"
      | summarize AvgAvailableMB = avg(CounterValue) by bin(TimeGenerated, 5m)
    QUERY

    time_aggregation_method = "Minimum"
    metric_measure_column   = "AvgAvailableMB"
    threshold               = 300
    operator                = "LessThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ag_windmill.id]
  }

  tags = local.common_tags
}

# Manages a Scheduled Query Rule (log alert) - low available disk space 
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "alert_disk_space_windmill" {
  name                    = "alert-low-disk-space-windmill"
  resource_group_name     = azurerm_resource_group.rg_windmill.name
  location                = local.location
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  scopes                  = [azurerm_log_analytics_workspace.log_windmill.id]
  severity                = 1
  description             = "Fires when vailable disk space is at 15%"
  display_name            = "alert-low-disk-space-windmill"
  enabled                 = true
  auto_mitigation_enabled = true


  criteria {
    query = <<-QUERY
      Perf
      | where CounterName == "% Free Space"
      | where InstanceName in ("/", "/datadisk")
      | summarize FreePct = avg(CounterValue) by InstanceName, bin(TimeGenerated, 5m)
    QUERY

    time_aggregation_method = "Minimum"
    metric_measure_column   = "FreePct"
    threshold               = 15
    operator                = "LessThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }

    dimension {
      name     = "InstanceName"
      operator = "Include"
      values   = ["*"] # include * creates separate alerts for both disks
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ag_windmill.id]
  }

  tags = local.common_tags
}


# Manages a Scheduled Query Rule (log alert) - no heartbeat from vm 
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "alert_vm_down_windmill" {
  name                    = "alert-vm-down-windmill"
  resource_group_name     = azurerm_resource_group.rg_windmill.name
  location                = local.location
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  scopes                  = [azurerm_log_analytics_workspace.log_windmill.id]
  severity                = 0
  description             = "Fires when no heartbeats received from vm-windmill in the 10mins window"
  display_name            = "alert-vm-down-windmill"
  enabled                 = true
  auto_mitigation_enabled = true

  criteria {
    query = <<-QUERY
      Heartbeat
      | where Computer == "vm-windmill"
    QUERY

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "LessThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ag_windmill.id]
  }

  tags = local.common_tags
}