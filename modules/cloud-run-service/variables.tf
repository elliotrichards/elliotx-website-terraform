variable "project_id" {
  type        = string
  description = "GCP project that owns the service"
}

variable "region" {
  type        = string
  description = "Region for the service, e.g. us-west1"
}

variable "name" {
  type        = string
  description = "Service name"
}

variable "description" {
  type    = string
  default = ""
}

variable "image" {
  type        = string
  description = "Container image to run. Defaults to Google's public placeholder so the first `terraform apply` succeeds before CI has pushed anything — see the lifecycle block on the service resource."
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "service_account_email" {
  type        = string
  description = "Runtime identity the service executes as"
}

variable "port" {
  type        = number
  description = "Port the container listens on"
  default     = 8080
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "secret_environment_variables" {
  type        = map(string)
  description = "Map of env var name -> Secret Manager secret ID. Cloud Run fetches the latest version itself using the runtime SA's secretAccessor grant — the app never needs the Secret Manager SDK."
  default     = {}
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type        = string
  description = "Cloud Run requires >=512Mi when CPU is always-allocated (the default here)"
  default     = "512Mi"
}

variable "min_instance_count" {
  type    = number
  default = 0
}

variable "max_instance_count" {
  type    = number
  default = 3
}

variable "allow_unauthenticated" {
  type        = bool
  description = "Grant invoker to allUsers — set false to require IAM auth on invoke"
  default     = true
}
