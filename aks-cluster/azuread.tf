# Create Azure AD Group for AKS Admins
resource "azuread_group" "aks_administrators" {
  display_name     = "${local.rg_name}-cluster-administrators"
  security_enabled = true
  description      = "Azure AKS Kubernetes administrators for the ${local.rg_name} cluster."
}