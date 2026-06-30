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
  # TODO(work-subscription port): implement customer-managed-key encryption via a
  # disk_encryption_set. Skipped on this dev subscription because CMK requires the
  # Key Vault to have purge protection ENABLED, which is intentionally off here for
  # clean teardown (CKV_AZURE_110). Disk is still encrypted at rest with a
  # platform-managed key by default.
  #checkov:skip=CKV_AZURE_93:Dev subscription uses platform-managed key encryption; enable CMK/disk_encryption_set when porting to the work subscription.
  name                 = "disk-windmill-pgdata"
  location             = local.location
  resource_group_name  = azurerm_resource_group.rg_windmill.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  tags                 = local.common_tags

  # Disk is only ever attached to the VM — it needs no network export/import path.
  # Lock it down (this does not affect the VM reading/writing the attached disk).
  public_network_access_enabled = false
  network_access_policy         = "DenyAll"

  lifecycle {
    # TEMP(UK West migration): disabled so the region change can replace this disk —
    # the dev DB is disposable. Set back to true after the rebuild applies cleanly.
    prevent_destroy = false
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "pgdata" {
  managed_disk_id    = azurerm_managed_disk.pgdata.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm_windmill.id
  lun                = 0
  caching            = "None" # safest for DB durability; no host write cache
}
