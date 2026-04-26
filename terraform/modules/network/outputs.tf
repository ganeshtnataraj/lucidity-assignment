output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.network.vnet_subnets[0]
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.network.vnet_id
}
