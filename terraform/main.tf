# Azure Provider source and version being used
terraform {
  required_version = "~> 1.15"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Terraform state file 
  backend "azurerm" {
    use_oidc             = true
    use_azuread_auth     = true
    resource_group_name  = "rg-windmill"
    storage_account_name = "stwindmilltf"
    container_name       = "tfstate"
    key                  = "windmill-dev.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    key_vault {
      recover_soft_deleted_key_vaults = false
      purge_soft_delete_on_destroy    = true
    }
  }
  use_oidc                        = true
  resource_provider_registrations = "none"
}
