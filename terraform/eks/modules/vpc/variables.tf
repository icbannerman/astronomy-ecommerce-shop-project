variable "vpc_cidr" {
  description = "Address range for the whole VPC, e.g. 10.0.0.0/16"
  type        = string
}

variable "availability_zones" {
  description = "AZs to spread subnets across, e.g. [us-east-2a, us-east-2b]"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One private subnet range per AZ (worker nodes live here)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One public subnet range per AZ (NAT gateway, load balancers)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name; used in resource names and the tags EKS looks for"
  type        = string
}
