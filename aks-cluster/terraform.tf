terraform {
  required_version = ">= 1.2.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # pin a tested major version for stability, e.g. "~> 3.0"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0.0, < 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.7.2"
    }
  }
}