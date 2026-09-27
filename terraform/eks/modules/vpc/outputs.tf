# What the VPC module hands back to whoever calls it (the root main.tf → the EKS module).

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS worker nodes go here)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancers go here)"
  value       = aws_subnet.public[*].id
}
