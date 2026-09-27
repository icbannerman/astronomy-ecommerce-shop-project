terraform {
  required_version = ">= 1.10" # use_lockfile needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in the bucket created by terraform/backend.
  # use_lockfile = S3-native locking (Terraform 1.10+), no DynamoDB table needed.
  backend "s3" {
    bucket       = "astronomy-shop-tfstate-005311909745"
    key          = "workstation/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "astronomy-ecommerce-shop"
      ManagedBy = "terraform"
    }
  }
}
