module "network" {
  source  = "Azure/network/azurerm"
  version = "~> 5.3"

  resource_group_name = var.resource_group_name
  use_for_each        = false
  vnet_name           = "${var.prefix}-vnet"
  address_space       = var.address_space
  subnet_names        = ["aks-subnet"]
  subnet_prefixes     = [var.aks_subnet_prefix]
  tags                = var.tags
}
