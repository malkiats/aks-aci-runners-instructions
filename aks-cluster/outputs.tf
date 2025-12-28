output "location" {
  value = azurerm_resource_group.main.location
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_versions" {
  value = data.azurerm_kubernetes_service_versions.current.versions
}

output "latest_kubernetes_version" {
  value = data.azurerm_kubernetes_service_versions.current.latest_version
}

output "azure_ad_group_object_id" {
  value     = azuread_group.aks_administrators.object_id
  sensitive = true
}

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.aks_cluster.id
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_cluster_kubernetes_version" {
  value = azurerm_kubernetes_cluster.aks_cluster.kubernetes_version
}