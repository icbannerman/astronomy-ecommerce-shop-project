variable "cluster_name" {
  description = "EKS cluster name; used in resource names and IAM role names"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the control plane, e.g. 1.31"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the cluster and worker nodes use (private subnets, from the vpc module)"
  type        = list(string)
}

variable "node_groups" {
  description = "One entry per managed node group: instance size and scaling limits"
  type = map(object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
  }))
}
