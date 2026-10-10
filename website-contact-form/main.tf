locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
  ]

  # ../last-fm-now-playing created this pool (it was the first app) — its
  # own state owns the resource, so it's addressed here by its deterministic
  # resource name rather than a cross-state data source.
  github_oidc_pool_name = "projects/${var.project_number}/locations/global/workloadIdentityPools/apps-github-pool"

  secret_ids = {
    TURNSTILE_SECRET_KEY = var.turnstile_secret_id
    RESEND_API_KEY       = var.resend_secret_id
    CONTACT_TO           = var.contact_to_secret_id
  }
}

resource "google_project_service" "this" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Runtime identity for the deployed service — only granted secretAccessor on
# its own three secrets below, nothing project-wide.
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "contact-form-run"
  display_name = "Contact form Cloud Run runtime"
  depends_on   = [google_project_service.this]
}

module "artifact_registry" {
  source        = "../modules/artifact-registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  format        = "DOCKER"
  description   = "Container images for the website contact form Cloud Run service"

  writer_members = [
    "serviceAccount:${module.contact_form_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# Secret containers only — values are added out-of-band
# (`gcloud secrets versions add`) so they never land in state or this repo.
module "secret" {
  for_each   = local.secret_ids
  source     = "../modules/secret"
  project_id = var.project_id
  secret_id  = each.value

  accessor_members = [
    "serviceAccount:${google_service_account.runtime.email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

module "cloud_run" {
  count       = var.create_service ? 1 : 0
  source      = "../modules/cloud-run-service"
  project_id  = var.project_id
  region      = var.region
  name        = var.service_name
  description = "Receives elliotx.com contact form posts, verifies Turnstile, emails them via Resend"

  service_account_email = google_service_account.runtime.email
  # Only reachable through the site's load balancer (elliotx.com/api/contact,
  # see ../main.tf) — the *.run.app URL refuses public traffic. allUsers
  # invoker is still needed: the load balancer forwards requests
  # unauthenticated, and the app does its own checks (origin, Turnstile).
  ingress               = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  allow_unauthenticated = true
  max_instance_count    = 2

  environment_variables = {
    ALLOWED_ORIGIN     = var.site_origin
    TURNSTILE_HOSTNAME = var.site_hostname
    CONTACT_FROM       = var.contact_from
  }
  secret_environment_variables = {
    for env_name, mod in module.secret : env_name => mod.secret_id
  }

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}
