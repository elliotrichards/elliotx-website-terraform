locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Runtime identity for the deployed service — only granted secretAccessor on
# its own secret below, nothing project-wide.
resource "google_service_account" "function_runtime" {
  project      = var.project_id
  account_id   = "lastfm-now-playing-fn"
  display_name = "NowPlaying Cloud Run runtime"
  depends_on   = [google_project_service.this]
}

module "artifact_registry" {
  source        = "../modules/artifact-registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  format        = "DOCKER"
  description   = "Container images for the NowPlaying (last.fm) Cloud Run service"

  writer_members = [
    "serviceAccount:${module.now_playing_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

module "secret" {
  source     = "../modules/secret"
  project_id = var.project_id
  secret_id  = var.secret_id

  accessor_members = [
    "serviceAccount:${google_service_account.function_runtime.email}",
  ]
  version_manager_members = [
    "serviceAccount:${module.now_playing_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

module "cloud_run" {
  source      = "../modules/cloud-run-service"
  project_id  = var.project_id
  region      = var.region
  name        = var.service_name
  description = "Returns the currently-playing last.fm track for the Cord widget"

  service_account_email = google_service_account.function_runtime.email
  allow_unauthenticated = true

  environment_variables = {
    LASTFM_USERNAME = var.lastfm_username
  }
  secret_environment_variables = {
    LASTFM_API_KEY = module.secret.secret_id
  }

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}
