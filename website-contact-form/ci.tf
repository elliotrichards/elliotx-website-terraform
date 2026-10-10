# This app's own deploy identity, bound to the shared apps pool (see
# local.github_oidc_pool_name in main.tf).
module "contact_form_ci" {
  source      = "../modules/github-ci-service-account"
  project_id  = var.project_id
  pool_name   = local.github_oidc_pool_name
  github_repo = var.apps_github_repo

  service_account_id           = "contact-form-ci"
  service_account_display_name = "Contact form CI (GitHub Actions)"

  # artifactregistry.writer is granted directly on the repository
  # (module.artifact_registry), not project-wide. GitHub Actions builds and
  # pushes the image itself, so just run.developer to deploy the service.
  project_role_grants = [
    "roles/run.developer",
  ]

  depends_on = [google_project_service.this]
}

# Lets the CI SA deploy new revisions running as the service's runtime SA.
resource "google_service_account_iam_member" "github_ci_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.contact_form_ci.service_account_email}"
}

# Terraform itself (running as terraform-ci) also needs actAs on this SA to
# create a service whose runtime identity is this SA.
resource "google_service_account_iam_member" "terraform_ci_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_ci_service_account_email}"
}

# terraform-ci already holds run.admin, artifactregistry.admin and
# secretmanager.admin project-wide (granted by ../last-fm-now-playing), so
# no new project roles here — just a buffer for the actAs grant above, which
# the first apply needs before it can create the service.
resource "time_sleep" "terraform_ci_iam_propagation" {
  create_duration = "60s"
  depends_on = [
    google_service_account_iam_member.terraform_ci_act_as_runtime,
  ]
}
