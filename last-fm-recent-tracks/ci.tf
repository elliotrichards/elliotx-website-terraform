# This app's own deploy identity, bound to the shared pool created in
# ../last-fm-now-playing (module.github_oidc_pool) — trust is repo-scoped,
# not path-scoped, so this app just trusts the existing pool rather than
# creating a second one.
module "recent_tracks_ci" {
  source      = "../modules/github-ci-service-account"
  project_id  = var.project_id
  pool_name   = local.github_oidc_pool_name
  github_repo = var.apps_github_repo

  service_account_id           = "lastfm-recent-tracks-ci"
  service_account_display_name = "RecentTracks CI (GitHub Actions)"

  # artifactregistry.writer (module.artifact_registry) is granted directly
  # on that resource, not project-wide. No Cloud Build involved — GitHub
  # Actions runs `docker build`/`docker push` itself and deploys the image
  # directly, so just run.developer to deploy the Cloud Run service. This CI
  # SA never touches Secret Manager or BigQuery — only Terraform (via
  # terraform-ci below) manages those.
  project_role_grants = [
    "roles/run.developer",
  ]

  depends_on = [google_project_service.this]
}

# Lets the CI SA deploy new revisions running as the service's runtime SA.
resource "google_service_account_iam_member" "github_ci_act_as_function_runtime" {
  service_account_id = google_service_account.function_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.recent_tracks_ci.service_account_email}"
}

# Terraform itself (running as terraform-ci) also needs actAs on this SA —
# creating a resource with its runtime identity set to this SA requires the
# *caller* to have iam.serviceaccounts.actAs, separate from the grant above
# which only covers the app repo's own CI-driven redeploys.
resource "google_service_account_iam_member" "terraform_ci_act_as_function_runtime" {
  service_account_id = google_service_account.function_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_ci_service_account_email}"
}

# Same reasoning, for the Scheduler job's oidc_token.service_account_email —
# creating the Scheduler job requires terraform-ci to actAs the invoker SA.
resource "google_service_account_iam_member" "terraform_ci_act_as_scheduler_invoker" {
  service_account_id = google_service_account.scheduler_invoker.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_ci_service_account_email}"
}

# --- Extend the repo-wide terraform-ci SA (../iam.tf) so it can manage the
# resource types this subfolder introduces. Declared here, not in the root
# state, to keep this app's infra additions self-contained. ---

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

resource "google_project_iam_member" "terraform_ci_bigquery_admin" {
  project    = var.project_id
  role       = "roles/bigquery.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "terraform_ci_cloudscheduler_admin" {
  project    = var.project_id
  role       = "roles/cloudscheduler.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

# Resource-scoped to just this one secret, rather than the project-wide
# secretmanager.admin ../last-fm-now-playing's state already grants — this
# app's own state doesn't depend on a sibling state's resources, self-
# contained the same way the roles above are. secretmanager.admin (there's
# no narrower Secret Manager role that only covers setIamPolicy) is what
# lets terraform-ci grant this app's runtime SA secretAccessor on it below.
resource "google_secret_manager_secret_iam_member" "terraform_ci_secret_admin" {
  project    = var.project_id
  secret_id  = var.secret_id
  role       = "roles/secretmanager.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

# IAM grants are eventually consistent — the very first apply that grants
# terraform-ci these roles also needs to *use* them (creating the AR repo,
# the BigQuery dataset, the secret IAM binding, the service, the Scheduler
# job) in the same run. Without a buffer, those calls can 403 before the
# policy has propagated. Anything created below that relies on the admin
# roles above depends on this.
resource "time_sleep" "terraform_ci_iam_propagation" {
  create_duration = "60s"
  depends_on = [
    google_project_iam_member.terraform_ci_run_admin,
    google_project_iam_member.terraform_ci_artifactregistry_admin,
    google_project_iam_member.terraform_ci_bigquery_admin,
    google_project_iam_member.terraform_ci_cloudscheduler_admin,
    google_secret_manager_secret_iam_member.terraform_ci_secret_admin,
    google_service_account_iam_member.terraform_ci_act_as_function_runtime,
    google_service_account_iam_member.terraform_ci_act_as_scheduler_invoker,
  ]
}
