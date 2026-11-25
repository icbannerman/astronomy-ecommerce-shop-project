output "role_arn" {
  description = "IAM role the controller's service account assumes"
  value       = aws_iam_role.this.arn
}
