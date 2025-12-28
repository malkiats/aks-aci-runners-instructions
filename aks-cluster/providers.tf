provider "azurerm" {
  features = {}
  # Recommended: pin provider version in required_providers (see terraform block)
}

provider "azuread" {
  # Configuration optional - uses env auth or CLI auth
}