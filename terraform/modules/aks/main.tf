module "aks" {
  source  = "Azure/aks/azurerm"
  version = "~> 9.4"

  resource_group_name = var.resource_group_name
  location            = var.location
  prefix              = var.prefix
  kubernetes_version  = var.kubernetes_version
  agents_count        = var.node_count
  agents_size         = var.node_vm_size
  vnet_subnet_id      = var.subnet_id
  network_plugin                  = "azure"
  role_based_access_control_enabled = true
  rbac_aad                          = false
  os_disk_size_gb     = 50
  tags                = var.tags

  log_analytics_workspace_enabled = true
  log_retention_in_days           = 30
}
