# CI identity for the app repo (var.function_source_repo) to build the
# container image, push it to Artifact Registry, and deploy the function.
module "github_ci" {
  source      = "../modules/github-oidc"
  project_id  = var.project_id
  pool_id     = "now-playing-github-pool"
  provider_id = "now-playing-github-provider"
  github_repo = var.function_source_repo

  service_account_id           = "now-playing-ci"
  service_account_display_name = "NowPlaying CI (GitHub Actions)"

  # artifactregistry.writer (module.artifact_registry) and
  # secretmanager.secretVersionManager (module.secret) are granted directly
  # on those resources, not project-wide.
  project_role_grants = [
    "roles/cloudfunctions.developer",
    "roles/run.developer",
    "roles/cloudbuild.builds.editor",
  ]

  depends_on = [google_project_service.this]
}

# Lets the CI SA deploy new revisions running as the function's runtime SA.
resource "google_service_account_iam_member" "github_ci_act_as_function_runtime" {
  service_account_id = google_service_account.function_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.github_ci.service_account_email}"
}

# --- Extend the repo-wide terraform-ci SA (../iam.tf) so it can manage the
# resource types this subfolder introduces. Declared here, not in the root
# state, to keep this app's infra additions self-contained. ---

resource "google_project_iam_member" "terraform_ci_cloudfunctions_admin" {
  project    = var.project_id
  role       = "roles/cloudfunctions.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "terraform_ci_run_admin" {
  project    = var.project_id
  role       = "roles/run.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "terraform_ci_artifactregistry_admin" {
  project    = var.project_id
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "terraform_ci_secretmanager_admin" {
  project    = var.project_id
  role       = "roles/secretmanager.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}
