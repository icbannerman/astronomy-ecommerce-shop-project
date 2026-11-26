variable "application_file" {
  description = "Path to the Argo CD Application manifest (argocd/application.yaml)"
  type        = string
}

variable "alb_controller_release_id" {
  description = "ID of the ALB controller's Helm release. Only used for ordering (install after it, destroy before it)"
  type        = string
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (10.20.0 = Argo CD v3.6.3)"
  type        = string
  default     = "10.20.0"
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version"
  type        = string
  default     = "2.0.10"
}
