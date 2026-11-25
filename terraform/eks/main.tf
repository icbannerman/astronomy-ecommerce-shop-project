# Networking: VPC, subnets, NAT gateways, route tables.
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  cluster_name         = var.cluster_name
}

# EKS cluster and worker nodes, placed in the VPC built above.
module "eks" {
  source = "./modules/cluster"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnet_ids      = module.vpc.private_subnet_ids
  node_groups     = var.node_groups
}

# Ingress controller: turns the shop's Ingress into a real AWS ALB.
module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name    = module.eks.cluster_name
  region          = var.region
  vpc_id          = module.vpc.vpc_id
  oidc_issuer_url = module.eks.oidc_issuer_url

  # Wait for the whole cluster module, worker nodes included: Helm waits for the controller's
  # pods to be Running, and pods can't start until nodes exist.
  depends_on = [module.eks]
}
