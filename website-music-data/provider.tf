terraform {
  required_version = "~> 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.35.0"
    }
  }

  # Same state bucket as the main site config (../provider.tf), distinct
  # prefix — keeps this app's state, and blast radius, separate without
  # provisioning a second bucket.
  backend "gcs" {
    bucket = "elliotx-website-tfstate"
    prefix = "terraform/website-music-data/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
