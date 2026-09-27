terraform {
  required_version = ">= 1.10" # needed for S3-native state locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # This folder creates the state bucket itself, so its own state stays local
  # (chicken-and-egg). It's tiny, gitignored, and rarely changes.
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
