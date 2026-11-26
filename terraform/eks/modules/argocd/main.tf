# Argo CD and the shop's Application. Replaces the manual steps after every spin-up:
#   kubectl create namespace argocd
#   kubectl apply -n argocd --server-side -f .../install.yaml
#   kubectl apply -f argocd/application.yaml

# argocd/application.yaml stays the single source of truth for the Application; read it here.
locals {
  app = yamldecode(file(var.application_file))
}

# ① Wait for the ALB controller. Reading the value makes this wait until the controller is installed,
# and on destroy, Argo CD (and the shop it deployed) is removed BEFORE the controller, so the
# controller is still around to delete the shop's ALB.
resource "terraform_data" "after_alb_controller" {
  input = var.alb_controller_release_id
}

# ② Argo CD itself, from the official Helm chart (chart 10.20.0 = Argo CD v3.6.3).
# Release name "argocd" keeps the familiar names: argocd-server, argocd-initial-admin-secret, ...
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  depends_on = [terraform_data.after_alb_controller]
}

# ③ The Application, via the official "argocd-apps" chart. A Helm chart is used instead of a plain
# Kubernetes manifest because the Application type only exists after ② installs it; a chart is
# checked at install time, not at plan time, so a plan on an empty cluster still works.
# Fields come straight from argocd/application.yaml (name, namespace, finalizers, spec).
resource "helm_release" "apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      (local.app.metadata.name) = merge(local.app.spec, {
        namespace  = local.app.metadata.namespace
        finalizers = local.app.metadata.finalizers
      })
    }
  })]

  depends_on = [helm_release.argocd]
}
