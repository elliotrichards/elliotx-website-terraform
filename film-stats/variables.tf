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
  default = "film-stats"
}

variable "create_service" {
  type        = bool
  description = "Create the Cloud Run service and its Scheduler job. Cloud Run refuses to create a revision whose secret env vars have no version yet, so on a fresh project apply with this false first, add the TMDB token out-of-band, then set it true (same two-step bootstrap as ../website-contact-form)."
  default     = true
}

variable "sheet_id" {
  type        = string
  description = "ID of the watch-log Google Sheet (the long segment of its URL). Not a credential — the sheet is shared only with the runner SA — but kept out of git anyway; CI passes it from the FILM_STATS_SHEET_ID repo variable."

  validation {
    condition     = length(var.sheet_id) > 0
    error_message = "sheet_id is empty — set the FILM_STATS_SHEET_ID repository variable (or TF_VAR_sheet_id locally)."
  }
}

variable "sheet_tab" {
  type    = string
  default = "Watch Log"
}

variable "sheet_range" {
  type        = string
  description = "A1 range within sheet_tab, excluding the header row"
  default     = "A2:F"
}

variable "site_origin" {
  type        = string
  description = "Origin allowed by the public stats bucket's CORS policy, for a client-side fetch of stats.json"
  default     = "https://elliotx.com"
}

variable "schedule" {
  type        = string
  description = "Cron schedule for the daily run, interpreted in schedule_time_zone"
  default     = "0 5 * * *"
}

variable "schedule_time_zone" {
  type        = string
  description = "IANA time zone, not a fixed UTC offset — Cloud Scheduler applies the BST/GMT switch itself. Also passed to the app as its notion of \"today\" for streaks."
  default     = "Europe/London"
}

variable "secret_id" {
  type        = string
  description = "Secret Manager secret holding the TMDB API Read Access Token. Terraform owns the container only — the value is added out-of-band with `gcloud secrets versions add`, so it never lands in state."
  default     = "tmdb-api-token"
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "film-stats"
}

variable "alert_email" {
  type        = string
  description = "Where failed-run alerts go. Empty disables the alert policy entirely. CI passes it from the FILM_STATS_ALERT_EMAIL repo variable."
  default     = ""
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
