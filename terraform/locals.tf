locals {
  location = "UK West"
  # Pinned to the RG's existing region. An RG's location is only metadata for its
  # own record (child resources may live in any region), and azurerm treats it as
  # ForceNew — tying it to local.location would destroy/recreate rg-windmill, which
  # holds the state backend (stwindmilltf). Keep this fixed to avoid replacing it.
  rg_location = "UK South"
  common_tags = {
    environment = "dev",
    managed-by  = "https://github.com/michal-karol/windmill",
    project     = "windmill",
    owner       = "Michal Slotwinski",
    team        = "IT Ops"
  }
}
