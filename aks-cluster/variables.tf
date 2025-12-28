variable "location" {
  description = "Azure region to deploy resources into"
  type        = string
}

variable "resource_group_base_name" {
  description = "Base name for the resource group (will be suffixed with environment)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/test/prod)"
  type        = string
  default     = "dev"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-cluster"
}

variable "ssh_public_key" {
  description = "Path to SSH public key for Linux nodes"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "windows_admin_username" {
  description = "Windows admin username for Windows nodes"
  type        = string
  default     = "azureuser"
}

variable "windows_admin_password" {
  description = "Windows admin password for Windows nodes (sensitive)"
  type        = string
  sensitive   = true
  default     = null
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {}
}