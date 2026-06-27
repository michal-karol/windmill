# Persistent data disk for the Postgres database. Kept as SEPARATE resources from
# the VM so it survives VM replacement: changes to custom_data/image/size/ssh key
# force-replace azurerm_linux_virtual_machine.vm_windmill, but this disk (and its
# data) is untouched and simply re-attached to the new VM. The Postgres data dir
# is bind-mounted onto this disk via cloud-init.
#
# NOTE: prevent_destroy is enabled below — Terraform will REFUSE to destroy this
# disk (so `terraform destroy` and any plan that would delete/replace it fail
# loudly, protecting the database). To intentionally tear it down later, remove
# the lifecycle block (or `terraform state rm`) first.
resource "azurerm_managed_disk" "pgdata" {
  name                 = "disk-windmill-pgdata"
  location             = local.location
  resource_group_name  = azurerm_resource_group.rg_windmill.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  tags                 = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "pgdata" {
  managed_disk_id    = azurerm_managed_disk.pgdata.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm_windmill.id
  lun                = 0
  caching            = "None" # safest for DB durability; no host write cache
}
