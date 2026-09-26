# Copy to terraform.tfvars (gitignored) and fill in:
#   cp example.tfvars terraform.tfvars

key_name     = "udemy-devops-project" # EC2 console → Key Pairs (must exist in the region)
allowed_cidr = "203.0.113.10/32"      # your public IP + /32. Find it with: curl -s https://checkip.amazonaws.com

# Optional overrides:
# region         = "us-east-2"
# instance_type  = "t2.large"
# root_volume_gb = 30
