variable "allowed_source_ip" {
  type        = string
  description = "Source IP in CIDR notation (e.g. 1.2.3.4/32) allowed inbound on ports 443"
}

variable "tf_principal_object_id" {
  type        = string
  description = "Object ID of the service principal Terraform authenticates as. Used for the Key Vault Secrets Officer role assignment. Sourced from CI (TF_VAR_tf_principal_object_id) because azurerm_client_config.object_id is unreliable under OIDC."
}

variable "plan_principal_object_id" {
  type        = string
  description = "Object ID of the read-only service principal used by the plan/drift workflows. Granted Key Vault Secrets User so terraform refresh can read managed secrets. Sourced from CI (TF_VAR_plan_principal_object_id)."
}