variable "region" {
  description = "AWS region for the workstation."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name tag for the instance and prefix for related resources."
  type        = string
  default     = "devops-workstation"
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro (1 vCPU / 1 GB) is too small for this project."
  type        = string
  default     = "t2.large"
}

variable "root_volume_gb" {
  description = "Root EBS volume size. The default 8 GB fills up when pulling the demo's ~26 images."
  type        = number
  default     = 30
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in this region (EC2 console → Key Pairs)."
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach SSH and the app, e.g. \"203.0.113.10/32\" for your own IP."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && var.allowed_cidr != "0.0.0.0/0"
    error_message = "allowed_cidr must be a valid CIDR and must not be 0.0.0.0/0. Use your IP with /32."
  }
}

variable "app_ports" {
  description = "Extra inbound ports for the demo (8080 = Envoy frontend proxy)."
  type        = list(number)
  default     = [8080]
}
