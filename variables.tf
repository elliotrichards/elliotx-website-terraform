variable "domain_name" {
  type        = string
  description = "Domain name for the website"
}

variable "bucket_name" {
  type        = string
  description = "GCS bucket name for the static site"
}

variable "project_id" {
  type        = string
  description = "ID of the Google Project"
  default     = "elliotx"
}

variable "project_number" {
  type        = string
  description = "Project Number"
  default     = "362369312254"
}

variable "region" {
  type        = string
  description = "Default Region"
  default     = "us-west1"
}

variable "zone" {
  type        = string
  description = "Default Zone"
  default     = "us-west1-a"
}
