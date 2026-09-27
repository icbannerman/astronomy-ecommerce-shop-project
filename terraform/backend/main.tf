# S3 bucket that stores Terraform state for the rest of this project.
# Locking uses S3 itself (use_lockfile = true in each backend block), so no DynamoDB table.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  # e.g. astronomy-shop-tfstate-123456789012
  bucket = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}"

  # Losing this bucket means losing every state file, so block `terraform destroy` on it.
  lifecycle {
    prevent_destroy = true
  }
}

# Keep every previous version of each state file, so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (state files can contain secrets).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Never allow public access, whatever policies are added later.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Refuse any request that isn't over HTTPS.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}
