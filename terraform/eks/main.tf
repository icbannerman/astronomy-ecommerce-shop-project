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
  node_group_arns = module.eks.node_group_arns # only the Helm install waits on these (see the module)
}

# Argo CD and the shop's Application. Argo CD then deploys the shop from Git.
module "argocd" {
  source = "./modules/argocd"

  application_file          = "${path.root}/../../argocd/application.yaml"
  alb_controller_release_id = module.alb_controller.helm_release_id
}
