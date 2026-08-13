variable "project_id" {
  type        = string
  description = "GCP project that owns the pool"
}

variable "pool_id" {
  type        = string
  description = "Workload Identity Pool ID (must be unique in the project)"
}

variable "pool_display_name" {
  type    = string
  default = ""
}

variable "provider_id" {
  type    = string
  default = "github-provider"
}

variable "github_repo" {
  type        = string
  description = "owner/repo allowed to federate via OIDC, e.g. elliotrichards/elliotx-website-apps. Trust is repo-scoped, not path-scoped — every app in this repo shares this pool, each with its own service account (see modules/github-ci-service-account)."
}
