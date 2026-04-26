variable "subscription_id" {
  description = "Azure Subscription ID to deploy resources into"
  type        = string
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "lucidity"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2alds_v7"
}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "CIDR for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "lucidity-assignment"
    environment = "dev"
    managed_by  = "terraform"
  }
}
