variable "project_id" {
  type        = string
  description = "GCP project ID"
  default     = "elliotx"
}

variable "project_number" {
  type        = string
  description = "GCP project number — used to address the shared apps WIF pool by name"
  default     = "362369312254"
}

variable "region" {
  type        = string
  description = "Region for this app's resources — matches the main site's default region and the serverless NEG in ../main.tf"
  default     = "us-west1"
}

variable "service_name" {
  type        = string
  description = "Cloud Run service name. ../main.tf's serverless NEG points at this name, so change both together."
  default     = "contact-form"
}

variable "create_service" {
  type        = bool
  description = "Create the Cloud Run service. Cloud Run refuses to create a revision whose secret env vars have no version yet, so on a fresh project apply with this false first, add the secret values out-of-band, then set it true."
  default     = true
}

variable "turnstile_secret_id" {
  type        = string
  description = "Secret Manager secret ID holding the Cloudflare Turnstile secret key"
  default     = "turnstile-secret-key"
}

variable "resend_secret_id" {
  type        = string
  description = "Secret Manager secret ID holding the Resend API key"
  default     = "resend-api-key"
}

variable "contact_to_secret_id" {
  type        = string
  description = "Secret Manager secret ID holding the inbox address messages are delivered to — a secret so the address stays out of this public repo and Terraform state"
  default     = "contact-to-email"
}

variable "site_origin" {
  type        = string
  description = "Origin the form is served from; the service rejects POSTs from any other Origin"
  default     = "https://elliotx.com"
}

variable "site_hostname" {
  type        = string
  description = "Hostname Turnstile must report the token was issued on"
  default     = "elliotx.com"
}

variable "contact_from" {
  type        = string
  description = "Sender address on delivered messages. Must be on a domain verified in Resend; no mailbox is needed behind it, since replies go to the visitor via reply_to."
  default     = "elliotx.com contact form <contact@elliotx.com>"
}

variable "artifact_registry_repository_id" {
  type    = string
  default = "contact-form"
}

variable "apps_github_repo" {
  type        = string
  description = "owner/repo hosting the app source + GitHub Actions deploy workflow — the shared apps WIF pool's trust boundary"
  default     = "elliotrichards/elliotx-website-apps"
}

variable "terraform_ci_service_account_email" {
  type        = string
  description = "The repo-wide terraform-ci SA (created in ../ci.tf) that plans/applies this subfolder too"
  default     = "terraform-ci@elliotx.iam.gserviceaccount.com"
}
