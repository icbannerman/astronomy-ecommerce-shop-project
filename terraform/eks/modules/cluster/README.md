# EKS module

Creates the EKS cluster (control plane) and its worker nodes (data plane) inside the VPC built
by the `vpc` module.

## Concepts

**EKS cluster (control plane)** — the Kubernetes "brain": API server, scheduler,
controller-manager, etcd. AWS runs this on AWS-owned infrastructure in an AWS-managed account;
it is **not an EC2 instance in your account** and you never see or manage the underlying servers.
You get billed a flat hourly rate for it and talk to it only through its API endpoint (the URL
`kubectl` uses).

**Node group (data plane)** — a *managed* set of EC2 instances (backed by an Auto Scaling Group)
that register themselves with the cluster's control plane and actually run your pods. These
**are** real EC2 instances in your account, in the subnets you choose — visible in the EC2
console, billed on your EC2 bill, sizeable between a min/desired/max count. AWS handles bootstrapping
them onto the cluster automatically (unlike self-managed nodes, where you'd write that yourself).

Relationship: the cluster can exist with zero node groups (nothing to schedule pods onto); a node
group always joins exactly one cluster.

## Steps this module follows (control plane, then data plane)

1. IAM role the EKS service can assume
2. Attach `AmazonEKSClusterPolicy` to that role
3. `aws_eks_cluster` — the control plane itself
4. IAM role EC2 can assume (for worker nodes)
5. Attach `AmazonEKSWorkerNodePolicy`, `AmazonEKSCNIPolicy`, `AmazonEC2ContainerRegistryReadOnly`
6. `aws_eks_node_group` — the EC2 worker nodes, joined to the cluster from step 3

## Inputs and outputs

| Inputs (`variables.tf`) | Outputs (`outputs.tf`) |
|---|---|
| `cluster_name`, `cluster_version`, `vpc_id`, `subnet_ids`, node group sizing | `cluster_endpoint`, `cluster_name` |
