# AWS Load Balancer Controller: the Ingress controller that turns an `Ingress` object into a real
# AWS ALB. Replaces the manual eksctl/aws/helm steps from notes/K8S_NOTES.md section 19, so every
# `terraform apply` sets it up and every `terraform destroy` removes it.

# The cluster's OIDC issuer URL without "https://", used as a prefix in the role's trust conditions.
locals {
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
}

# ① Read the TLS certificate of the cluster's OIDC issuer, so IAM can pin its fingerprint.
data "tls_certificate" "oidc" {
  url = var.oidc_issuer_url
}

# ② Make IAM trust identity tokens issued by this cluster.
# Was: eksctl utils associate-iam-oidc-provider
resource "aws_iam_openid_connect_provider" "this" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

# ③ The permissions the controller needs (create/modify ALBs, target groups, security groups...).
# iam_policy.json is AWS's official policy for controller v3.5.0, matching var.chart_version.
# Was: aws iam create-policy
resource "aws_iam_policy" "this" {
  name   = "${var.cluster_name}-alb-controller"
  policy = file("${path.module}/iam_policy.json")
}

# ④ A role that ONLY the controller's Kubernetes service account can assume (this is IRSA).
# The conditions check the token's "sub" (which service account) and "aud" (meant for AWS STS),
# so no other pod in the cluster can borrow these permissions.
# Was: eksctl create iamserviceaccount
resource "aws_iam_role" "this" {
  name = "${var.cluster_name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:${var.service_account_name}"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# ⑤ Attach the permissions (③) to the role (④).
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

# Holds the node group ARNs. Reading var.node_group_arns here makes this wait until the worker nodes
# exist. The Helm install depends on this, instead of the whole module depending on module.eks,
# so a node-count change no longer makes Terraform re-check the OIDC certificate (① and ②).
resource "terraform_data" "nodes_ready" {
  input = var.node_group_arns
}

# ⑥ Install the controller itself from AWS's Helm chart.
# Unlike the manual install, Helm creates the service account here, annotated with the role ARN
# (that annotation is what links the service account to the IAM role from ④).
# Was: helm install aws-load-balancer-controller eks/aws-load-balancer-controller ...
resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  set = [
    { name = "clusterName", value = var.cluster_name },
    { name = "region", value = var.region },
    { name = "vpcId", value = var.vpc_id }, # which VPC to create load balancers in
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = var.service_account_name },
    # Dots inside the annotation key are escaped so Helm doesn't read them as nesting.
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.this.arn },
  ]

  # The controller must have its permissions before its pods start calling AWS, and its pods need
  # worker nodes to run on (Helm waits for them to be Running).
  depends_on = [aws_iam_role_policy_attachment.this, terraform_data.nodes_ready]
}
