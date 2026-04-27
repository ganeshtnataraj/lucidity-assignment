terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {
    resource_group_name  = "lucidity-tfstate-rg"
    storage_account_name = "luciditytfstate"
    container_name       = "tfstate"
    key                  = "lucidity-demo.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "resource_group" {
  source   = "./modules/resource_group"
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

module "network" {
  source              = "./modules/network"
  resource_group_name = module.resource_group.name
  prefix              = var.prefix
  address_space       = var.vnet_address_space
  aks_subnet_prefix   = var.aks_subnet_prefix
  tags                = var.tags

  depends_on = [module.resource_group]
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = module.resource_group.name
  location            = var.location
  prefix              = var.prefix
  kubernetes_version  = var.kubernetes_version
  node_count          = var.node_count
  node_vm_size        = var.node_vm_size
  subnet_id           = module.network.aks_subnet_id
  tags                = var.tags

  depends_on = [module.resource_group]
}

