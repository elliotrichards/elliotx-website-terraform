variable "project_id" {
  type        = string
  description = "GCP project that owns the function"
}

variable "region" {
  type        = string
  description = "Region for the function, e.g. us-west1"
}

variable "name" {
  type        = string
  description = "Function name"
}

variable "description" {
  type    = string
  default = ""
}

variable "runtime" {
  type        = string
  description = "Cloud Functions runtime, e.g. nodejs20"
  default     = "nodejs20"
}

variable "entry_point" {
  type        = string
  description = "Exported function name the source must expose — also used to generate the placeholder source's export"
}

variable "service_account_email" {
  type        = string
  description = "Runtime identity the function executes as"
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "available_memory" {
  type    = string
  default = "256M"
}

variable "timeout_seconds" {
  type    = number
  default = 30
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
