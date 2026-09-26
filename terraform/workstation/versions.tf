terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for now. Moves to an S3 backend with DynamoDB locking in the EKS section.
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
