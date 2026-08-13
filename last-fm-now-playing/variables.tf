variable "project_id" {
  type        = string
  description = "GCP project ID"
  default     = "elliotx"
}

variable "region" {
  type        = string
  description = "Region for this app's resources — matches the main site's default region"
  default     = "us-west1"
}

variable "service_name" {
  type    = string
  default = "lastfm-now-playing"
}

variable "secret_id" {
  type        = string
  description = "Secret Manager secret ID holding the last.fm API key"
  default     = "lastfm-api-key"
}

variable "lastfm_username" {
  type        = string
  description = "last.fm username to query recent tracks for. Public data, not a secret — kept out of app source so it's not hardcoded."
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "now-playing"
}

variable "apps_github_repo" {
  type        = string
  description = "owner/repo hosting this and future apps' source + GitHub Actions deploy workflows. This is the WIF trust boundary for the whole shared pool below (module.github_oidc_pool) — trust is repo-scoped, not path-scoped, so every app in this repo shares the pool and gets its own service account."
  default     = "elliotrichards/elliotx-website-apps"
}

variable "terraform_ci_service_account_email" {
  type        = string
  description = "The repo-wide terraform-ci SA (created in ../iam.tf) that plans/applies this subfolder too — granted the extra roles it needs for the resource types introduced here."
  default     = "terraform-ci@elliotx.iam.gserviceaccount.com"
}
