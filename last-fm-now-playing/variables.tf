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

variable "function_name" {
  type    = string
  default = "lastfm-now-playing"
}

variable "function_entry_point" {
  type        = string
  description = "Exported function name the Node.js source must expose"
  default     = "nowPlaying"
}

variable "secret_id" {
  type        = string
  description = "Secret Manager secret ID holding the last.fm API key"
  default     = "lastfm-api-key"
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "now-playing"
}

variable "function_source_repo" {
  type        = string
  description = "owner/repo hosting the Node.js function source and its GitHub Actions deploy workflow. This is the WIF trust boundary for the CI service account below — update it once the repo exists."
  default     = "elliotrichards/last-fm-now-playing"
}

variable "terraform_ci_service_account_email" {
  type        = string
  description = "The repo-wide terraform-ci SA (created in ../iam.tf) that plans/applies this subfolder too — granted the extra roles it needs for the resource types introduced here."
  default     = "terraform-ci@elliotx.iam.gserviceaccount.com"
}
