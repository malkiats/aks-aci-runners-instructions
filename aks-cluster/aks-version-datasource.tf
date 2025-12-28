# Query Azure AKS versions for the selected location (non-preview)
data "azurerm_kubernetes_service_versions" "current" {
  location        = azurerm_resource_group.main.location
  include_preview = false
}