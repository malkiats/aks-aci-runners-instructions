resource "random_pet" "workspace_suffix" {
  length    = 2
  separator = "-"
}

resource "azurerm_log_analytics_workspace" "insights" {
  name                = "logs-${random_pet.workspace_suffix.id}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}