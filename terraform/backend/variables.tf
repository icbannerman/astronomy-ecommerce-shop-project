variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "us-east-2"
}

variable "bucket_prefix" {
  description = "Bucket name prefix. The AWS account ID is appended, because bucket names are globally unique."
  type        = string
  default     = "astronomy-shop-tfstate"
}
