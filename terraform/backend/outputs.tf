output "state_bucket" {
  description = "Use this as `bucket` in other folders' backend \"s3\" blocks."
  value       = aws_s3_bucket.state.id
}
