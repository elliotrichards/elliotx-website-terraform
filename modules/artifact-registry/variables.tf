variable "project_id" {
  type        = string
  description = "GCP project that owns the repository"
}

variable "location" {
  type        = string
  description = "Region for the repository, e.g. us-west1"
}

variable "repository_id" {
  type        = string
  description = "Repository ID"
}

variable "format" {
  type        = string
  description = "Repository format"
  default     = "DOCKER"
}

variable "description" {
  type    = string
  default = ""
}

variable "writer_members" {
  type        = list(string)
  description = "IAM members granted roles/artifactregistry.writer (push images)"
  default     = []
}

variable "reader_members" {
  type        = list(string)
  description = "IAM members granted roles/artifactregistry.reader (pull images)"
  default     = []
}
