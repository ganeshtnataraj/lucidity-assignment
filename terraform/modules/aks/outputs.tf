output "cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.aks_name
}

output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = module.aks.aks_id
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = module.aks.kube_config_raw
  sensitive   = true
}
