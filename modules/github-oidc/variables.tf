variable "project_id" {
  type        = string
  description = "GCP project that owns the pool and service account"
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
  description = "owner/repo allowed to federate via OIDC, e.g. elliotrichards/last-fm-now-playing"
}

variable "service_account_id" {
  type        = string
  description = "Account ID for the deploy service account this repo impersonates"
}

variable "service_account_display_name" {
  type    = string
  default = ""
}

variable "project_role_grants" {
  type        = list(string)
  description = "Project-level IAM roles granted to the deploy service account"
  default     = []
}
