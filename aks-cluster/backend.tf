# Configure remote state backend here (fill placeholders). Do NOT commit secrets.
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-storage-rg"  # update as needed
    storage_account_name = "terraformstoragemslab"      # update as needed
    container_name       = "tfstatefiles"
    key                  = "aks/terraform.tfstate"
  }
}