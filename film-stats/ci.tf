# This app's own deploy identity, bound to the shared pool created in
# ../last-fm-now-playing (module.github_oidc_pool) — trust is repo-scoped,
# not path-scoped, so this app just trusts the existing pool rather than
# creating a second one.
module "film_stats_ci" {
  source      = "../modules/github-ci-service-account"
  project_id  = var.project_id
  pool_name   = local.github_oidc_pool_name
  github_repo = var.apps_github_repo

  service_account_id           = "film-stats-ci"
  service_account_display_name = "Film stats CI (GitHub Actions)"

  # artifactregistry.writer (module.artifact_registry) is granted directly
  # on that resource, not project-wide. GitHub Actions builds and pushes the
  # image itself, so just run.developer to deploy it. This CI SA never
  # touches Secret Manager or the buckets.
  project_role_grants = [
    "roles/run.developer",
  ]

  depends_on = [google_project_service.this]
}

# Lets the CI SA deploy new revisions running as the runner SA.
resource "google_service_account_iam_member" "github_ci_act_as_runner" {
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.film_stats_ci.service_account_email}"
}

# Terraform itself (running as terraform-ci) also needs actAs on this SA —
# creating a resource with its runtime identity set to this SA requires the
# *caller* to have iam.serviceaccounts.actAs, separate from the grant above
# which only covers the app repo's own CI-driven redeploys.
resource "google_service_account_iam_member" "terraform_ci_act_as_runner" {
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_ci_service_account_email}"
}

# Same reasoning, for the Scheduler job's oidc_token.service_account_email.
resource "google_service_account_iam_member" "terraform_ci_act_as_scheduler" {
  service_account_id = google_service_account.scheduler.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_ci_service_account_email}"
}

# --- Extend the repo-wide terraform-ci SA (../iam.tf) so it can manage the
# resource types this subfolder introduces. Declared here, not in the root
# state, to keep this app's infra additions self-contained. ---
#
# Not repeated here: storage.admin (buckets), serviceAccountAdmin (the SAs)
# and serviceUsageAdmin (APIs) — the root state already grants all three
# project-wide, and a second google_project_iam_member for the same binding
# would remove it for the root state too if this folder were ever destroyed.

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

# Project-wide, unlike ../last-fm-recent-tracks's secret-scoped grant: this
# state *creates* its secret, and secrets.create only exists at project level.
resource "google_project_iam_member" "terraform_ci_secretmanager_admin" {
  project    = var.project_id
  role       = "roles/secretmanager.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "terraform_ci_cloudscheduler_admin" {
  project    = var.project_id
  role       = "roles/cloudscheduler.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

# Narrowest pair covering the alert policy and its email channel, rather
# than monitoring.editor (dashboards, uptime checks, metric writes, …).
resource "google_project_iam_member" "terraform_ci_alert_policy_editor" {
  project    = var.project_id
  role       = "roles/monitoring.alertPolicyEditor"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "terraform_ci_notification_channel_editor" {
  project    = var.project_id
  role       = "roles/monitoring.notificationChannelEditor"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

# A log-match alert policy (main.tf's run_failed) is stored by Cloud Logging
# as a notification rule, so creating one also needs
# logging.notificationRules.*, which no Monitoring role includes.
# configWriter is the narrowest predefined role that has it (terraform-ci
# can't create a custom role with just those five permissions).
resource "google_project_iam_member" "terraform_ci_logging_config_writer" {
  project    = var.project_id
  role       = "roles/logging.configWriter"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

# Separate from terraform_ci_iam_propagation below: that sleep already
# exists in state, so adding this grant to its depends_on wouldn't make it
# wait again. A new resource does get created (and waits) on the apply that
# adds the grant.
resource "time_sleep" "terraform_ci_logging_iam_propagation" {
  create_duration = "60s"
  depends_on      = [google_project_iam_member.terraform_ci_logging_config_writer]
}

# IAM grants are eventually consistent — the very first apply that grants
# terraform-ci these roles also needs to *use* them in the same run. Without
# a buffer, those calls can 403 before the policy has propagated. Anything
# created below that relies on the admin roles above depends on this.
resource "time_sleep" "terraform_ci_iam_propagation" {
  create_duration = "60s"
  depends_on = [
    google_project_iam_member.terraform_ci_run_admin,
    google_project_iam_member.terraform_ci_artifactregistry_admin,
    google_project_iam_member.terraform_ci_secretmanager_admin,
    google_project_iam_member.terraform_ci_cloudscheduler_admin,
    google_project_iam_member.terraform_ci_alert_policy_editor,
    google_project_iam_member.terraform_ci_notification_channel_editor,
    google_service_account_iam_member.terraform_ci_act_as_runner,
    google_service_account_iam_member.terraform_ci_act_as_scheduler,
  ]
}
