variable "cluster_name" {
  description = "EKS cluster name; the controller only manages load balancers for this cluster"
  type        = string
}

variable "region" {
  description = "AWS region the cluster runs in"
  type        = string
}

variable "vpc_id" {
  description = "VPC the controller creates load balancers in (from the vpc module)"
  type        = string
}

variable "oidc_issuer_url" {
  description = "The cluster's OIDC issuer URL (from the cluster module), e.g. https://oidc.eks.us-east-2.amazonaws.com/id/ABC123"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account the controller runs as, in kube-system"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "chart_version" {
  description = "Helm chart version; keep iam_policy.json in sync with the matching controller release"
  type        = string
  default     = "3.5.0"
}

variable "node_group_arns" {
  description = "Node group ARNs from the cluster module. Only used to make the Helm install wait for worker nodes"
  type        = list(string)
}
