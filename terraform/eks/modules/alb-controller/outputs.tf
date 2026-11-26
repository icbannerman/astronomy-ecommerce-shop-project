output "role_arn" {
  description = "IAM role the controller's service account assumes"
  value       = aws_iam_role.this.arn
}

output "helm_release_id" {
  description = "ID of the controller's Helm release; lets other modules install after it (and be destroyed before it)"
  value       = helm_release.this.id
}
