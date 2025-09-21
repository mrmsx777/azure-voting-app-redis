terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.114.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-platform-shared"
    storage_account_name = "tfstatemsx"
    container_name       = "tfstate"
    key                  = "azure-preprod.tfstate"
    use_azuread_auth     = true
  }
}
