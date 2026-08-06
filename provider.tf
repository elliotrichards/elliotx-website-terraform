terraform {
  required_version = "~> 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.35.0" # Minimum version for workbench_instance
    }
  }

  backend "gcs" {
    bucket = "elliotx-website-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}


provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
