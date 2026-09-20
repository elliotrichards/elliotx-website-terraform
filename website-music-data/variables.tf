variable "project_id" {
  type        = string
  description = "GCP project ID"
  default     = "elliotx"
}

variable "region" {
  type        = string
  description = "Region for this subfolder's resources — matches the main site's default region"
  default     = "us-west1"
}

variable "bq_dataset_id" {
  type        = string
  description = "BigQuery dataset this SA is granted read access to. Owned by ../last-fm-recent-tracks's Terraform state — this app is only granted dataViewer on it, never recreates it."
  default     = "lastfm"
}

variable "website_github_repo" {
  type        = string
  description = "owner/repo of the main site — the WIF trust boundary for its data-refresh GitHub Action. A different repo from ../last-fm-now-playing's apps_github_repo, so it needs its own pool (attribute_condition trusts exactly one repo)."
  default     = "elliotrichards/elliotx-website-v2"
}

variable "terraform_ci_service_account_email" {
  type        = string
  description = "The repo-wide terraform-ci SA (created in ../iam.tf) that plans/applies this subfolder too — granted the extra roles it needs for the resource types introduced here."
  default     = "terraform-ci@elliotx.iam.gserviceaccount.com"
}
