locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Runtime identity for the Cloud Function — only granted secretAccessor on
# its own secret below, nothing project-wide.
resource "google_service_account" "function_runtime" {
  project      = var.project_id
  account_id   = "lastfm-now-playing-fn"
  display_name = "NowPlaying Cloud Function runtime"
  depends_on   = [google_project_service.this]
}

module "artifact_registry" {
  source        = "../modules/artifact-registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  format        = "DOCKER"
  description   = "Container images for the NowPlaying (last.fm) Cloud Function"

  writer_members = [
    "serviceAccount:${module.github_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this]
}

module "secret" {
  source     = "../modules/secret"
  project_id = var.project_id
  secret_id  = var.secret_id

  accessor_members = [
    "serviceAccount:${google_service_account.function_runtime.email}",
  ]
  version_manager_members = [
    "serviceAccount:${module.github_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this]
}

module "cloud_function" {
  source      = "../modules/cloud-function"
  project_id  = var.project_id
  region      = var.region
  name        = var.function_name
  description = "Returns the currently-playing last.fm track for the Cord widget"

  runtime               = "nodejs20"
  entry_point           = var.function_entry_point
  service_account_email = google_service_account.function_runtime.email
  allow_unauthenticated = true

  environment_variables = {
    LASTFM_SECRET_NAME = module.secret.secret_id
  }

  depends_on = [google_project_service.this]
}
