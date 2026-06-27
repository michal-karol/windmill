variable "allowed_source_ip" {
  type        = string
  description = "Source IP in CIDR notation (e.g. 1.2.3.4/32) allowed inbound on ports 443"

  validation {
    condition     = can(cidrhost(trimspace(var.allowed_source_ip), 0))
    error_message = "allowed_source_ip must be valid CIDR notation, e.g. 1.2.3.4/32 (surrounding whitespace is tolerated)."
  }
}

variable "tf_principal_object_id" {
  type        = string
  description = "Object ID of the service principal Terraform authenticates as. Used for the Key Vault Secrets Officer role assignment. Sourced from CI (TF_VAR_tf_principal_object_id) because azurerm_client_config.object_id is unreliable under OIDC."
}

variable "plan_principal_object_id" {
  type        = string
  description = "Object ID of the read-only service principal used by the plan/drift workflows. Granted Key Vault Secrets User so terraform refresh can read managed secrets. Sourced from CI (TF_VAR_plan_principal_object_id)."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Postgres password, set once out-of-band via the GitHub secret DB_PASSWORD (TF_VAR_db_password). Written to Key Vault and read by the VM at boot. Must be URL-safe (it is interpolated raw into DATABASE_URL); generate with: openssl rand -hex 32."

  validation {
    condition     = can(regex("^[A-Za-z0-9._~-]+$", var.db_password)) && length(var.db_password) >= 16
    error_message = "db_password must be >=16 chars and URL-safe (only A-Z a-z 0-9 . _ ~ -); other characters break DATABASE_URL parsing."
  }
}