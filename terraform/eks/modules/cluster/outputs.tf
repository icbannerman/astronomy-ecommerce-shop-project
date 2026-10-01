output "cluster_endpoint" {
  description = "API server endpoint kubectl uses to talk to the control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name, needed by kubectl/aws eks update-kubeconfig"
  value       = aws_eks_cluster.main.name
}
