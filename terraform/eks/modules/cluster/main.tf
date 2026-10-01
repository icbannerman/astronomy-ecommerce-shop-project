# ① IAM role the EKS control plane assumes.
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ② Grant the cluster role permission to run the control plane.
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ③ The EKS cluster: the managed control plane (AWS-hosted, not an EC2 instance you can see).
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids # a list; AWS places the control plane's network interfaces across all of them
  }

  # Explicit dependency: nothing above returns a value this block needs, so there's no
  # natural reference to force the ordering. Without this, Terraform could try to create
  # the cluster before the role has permissions, and the AWS API call would fail.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ④ IAM role the worker node EC2 instances assume.
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ⑤ Grant the node role permission to join the cluster, use the CNI, and pull images.
# for_each here creates 3 separate IAM role-policy-attachment resources, one per ARN in the
# set (not 3 EC2 instances — this block has nothing to do with how many nodes get launched).
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value # each.value = the current ARN in this iteration of the loop
}

# ⑥ One or more node groups (a managed group of EC2 worker nodes each), one per entry in
# var.node_groups. for_each loops over the MAP KEYS of var.node_groups (e.g. just "general"
# by default) — it does NOT loop over worker nodes. How many actual EC2 instances a given
# node group runs is set separately below, by scaling_config.desired_size.
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  # aws_eks_cluster.main.name (an attribute reference), not var.cluster_name, so Terraform
  # also infers "create the cluster before this node group" — see the note on ③'s depends_on.
  cluster_name = aws_eks_cluster.main.name

  node_group_name = each.key # the map key you chose in var.node_groups, e.g. "general"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids # a list; AWS/the ASG spreads this group's EC2 instances across all of them

  instance_types = each.value.instance_types # each.value = this key's whole object, e.g. {instance_types, desired_size, min_size, max_size}

  scaling_config {
    desired_size = each.value.desired_size # the actual number of EC2 instances AWS launches for this node group
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  # Same reasoning as ③: the 3 policy attachments above don't produce a value this block
  # uses, so there's nothing to reference — depends_on is the only way to force AWS to grant
  # the node role its permissions before it tries to launch EC2 instances under that role.
  depends_on = [aws_iam_role_policy_attachment.node]
}

