resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = local.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.cluster_name
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  node_resource_group = local.node_resource_group

  default_node_pool {
    name                = "systempool"
    node_count          = 1
    vm_size             = "Standard_D2_v2"
    orchestrator_version = data.azurerm_kubernetes_service_versions.current.latest_version
    max_count           = 3
    min_count           = 0
    enable_auto_scaling = true
    os_disk_size_gb     = 30
    type                = "VirtualMachineScaleSets"
    node_labels = {
      nodepool-type = "system"
      environment   = var.environment
      nodepools     = "linux"
      app           = "system-apps"
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

  # RBAC & Azure AD Integration
  role_based_access_control {
    enabled = true

    # NOTE:
    # Depending on the azurerm provider version, this block's nested attributes differ.
    # For provider v3.x, use azure_active_directory as shown here.
    azure_active_directory {
      managed                = true
      admin_group_object_ids = [azuread_group.aks_administrators.object_id]
    }
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