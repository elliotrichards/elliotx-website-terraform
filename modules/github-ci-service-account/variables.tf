variable "project_id" {
  type        = string
  description = "GCP project that owns the service account"
}

variable "pool_name" {
  type        = string
  description = "Full resource name of an existing Workload Identity Pool (module.github_oidc_pool.pool_name) this SA trusts"
}

variable "github_repo" {
  type        = string
  description = "owner/repo allowed to impersonate this SA — must match the repo the pool's provider already trusts"
}

variable "service_account_id" {
  type        = string
  description = "Account ID for this app's deploy service account"
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
