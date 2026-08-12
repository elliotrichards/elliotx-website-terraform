variable "project_id" {
  type        = string
  description = "GCP project that owns the secret"
}

variable "secret_id" {
  type        = string
  description = "Secret Manager secret ID"
}

variable "accessor_members" {
  type        = list(string)
  description = "IAM members (e.g. \"serviceAccount:...\") granted roles/secretmanager.secretAccessor on this secret"
  default     = []
}

variable "version_manager_members" {
  type        = list(string)
  description = "IAM members granted roles/secretmanager.secretVersionManager on this secret, so they can add/rotate versions without project-wide Secret Manager admin"
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
