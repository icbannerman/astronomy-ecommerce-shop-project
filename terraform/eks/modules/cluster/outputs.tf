output "cluster_endpoint" {
  description = "API server endpoint kubectl uses to talk to the control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name, needed by kubectl/aws eks update-kubeconfig"
  value       = aws_eks_cluster.main.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA cert of the API server; lets the helm provider trust the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_issuer_url" {
  description = "The cluster's OIDC issuer URL, used to set up IRSA (IAM roles for service accounts)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_group_arns" {
  description = "ARNs of the node groups; known only once they exist, so other modules can wait for worker nodes"
  value       = [for ng in aws_eks_node_group.main : ng.arn]
}
