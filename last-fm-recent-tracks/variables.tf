variable "project_id" {
  type        = string
  description = "GCP project ID"
  default     = "elliotx"
}

variable "project_number" {
  type        = string
  description = "GCP project number — used to address the shared WIF pool created in ../last-fm-now-playing (module.github_oidc_pool), since Terraform state isn't shared across subfolders"
  default     = "362369312254"
}

variable "region" {
  type        = string
  description = "Region for this app's Cloud Run + Scheduler resources — matches the main site's default region"
  default     = "us-west1"
}

variable "service_name" {
  type    = string
  default = "lastfm-recent-tracks"
}

variable "secret_id" {
  type        = string
  description = "Secret Manager secret ID holding the last.fm API key. Owned by ../last-fm-now-playing's Terraform state — this app is only granted secretAccessor on it, never recreates or manages the secret container itself"
  default     = "lastfm-api-key"
}

variable "lastfm_username" {
  type        = string
  description = "last.fm username to query recent tracks for. Public data, not a secret — kept out of app source so it's not hardcoded. Same account as ../last-fm-now-playing."
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "recent-tracks"
}

variable "bq_dataset_id" {
  type    = string
  default = "lastfm"
}

variable "bq_table_id" {
  type    = string
  default = "recent_tracks"
}

variable "bq_location" {
  type        = string
  description = "BigQuery dataset location — a storage-only concern, independent of the Cloud Run region"
  default     = "US"
}

variable "schedule" {
  type        = string
  description = "Cron schedule for the daily pull, interpreted in schedule_time_zone"
  default     = "0 6 * * *"
}

variable "schedule_time_zone" {
  type        = string
  description = "IANA time zone, not a fixed UTC offset — Cloud Scheduler applies the BST/GMT switch itself"
  default     = "Europe/London"
}

variable "apps_github_repo" {
  type        = string
  description = "owner/repo hosting this and future apps' source + GitHub Actions deploy workflows — must match ../last-fm-now-playing (same WIF trust boundary)"
  default     = "elliotrichards/elliotx-website-apps"
}

variable "terraform_ci_service_account_email" {
  type        = string
  description = "The repo-wide terraform-ci SA (created in ../iam.tf) that plans/applies this subfolder too — granted the extra roles it needs for the resource types introduced here."
  default     = "terraform-ci@elliotx.iam.gserviceaccount.com"
}
