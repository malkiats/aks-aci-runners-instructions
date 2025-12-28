locals {
  rg_name             = "${var.resource_group_base_name}-${var.environment}"
  cluster_name        = "${local.rg_name}-cluster"
  node_resource_group = "${local.rg_name}-nrg"
  common_tags = merge({
    environment = var.environment
    terraform   = "true"
    owner       = "infra-team"
  }, var.tags)
}