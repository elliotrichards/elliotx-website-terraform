terraform {
  required_version = "~> 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.35.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Same state bucket as the main site config (../provider.tf), distinct
  # prefix — keeps this app's state, and blast radius, separate without
  # provisioning a second bucket.
  backend "gcs" {
    bucket = "elliotx-website-tfstate"
    prefix = "terraform/last-fm-now-playing/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
