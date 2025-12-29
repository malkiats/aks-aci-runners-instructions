resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = local.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.cluster_name
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  node_resource_group = local.node_resource_group

  default_node_pool {
    name                 = "systempool"
    vm_size              = "Standard_D2_v2"
    orchestrator_version = data.azurerm_kubernetes_service_versions.current.latest_version

    # enable autoscaling and capacity
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3

    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"

    # place AKS node pool into the Azure CNI subnet created above
    vnet_subnet_id = azurerm_subnet.aks_subnet.id

    node_labels = {
      "nodepool-type" = "system"
      environment     = var.environment
      nodepools       = "linux"
      app             = "system-apps"
    }

    tags = local.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  # Monitoring integration
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.insights.id
  }

  # Enable RBAC and configure Azure AD admin group
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [azuread_group.aks_administrators.object_id]
  }

  # Virtual Nodes (ACI) configuration - reference the ACI subnet name
  aci_connector_linux {
    # this must be the subnet name (string) that has the ACI delegation
    subnet_name = azurerm_subnet.aci_subnet.name
  }

  # Windows Profile - do not hardcode passwords in VCS. Provide via tfvars or CI secret.
  windows_profile {
    admin_username = var.windows_admin_username
    admin_password = var.windows_admin_password
  }

  linux_profile {
    admin_username = "ubuntu"
    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags = local.common_tags
}