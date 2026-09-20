# --- Extend the repo-wide terraform-ci SA (../iam.tf) so it can manage the
# resource types this subfolder introduces. Declared here, not in the root
# state, to keep this app's infra additions self-contained. ---

# Narrow, resource-scoped grant rather than project-wide bigquery.admin
# (../last-fm-recent-tracks's state already grants that project-wide, but
# this app's own state doesn't depend on a sibling state's resources —
# self-contained the same way the rest of this repo's ci.tf files are).
resource "google_bigquery_dataset_iam_member" "terraform_ci_dataset_admin" {
  project    = var.project_id
  dataset_id = var.bq_dataset_id
  role       = "roles/bigquery.admin"
  member     = "serviceAccount:${var.terraform_ci_service_account_email}"
  depends_on = [google_project_service.this]
}

# IAM grants are eventually consistent — the very first apply that grants
# terraform-ci this role also needs to *use* it (setting IAM on the
# dataset) in the same run. Without a buffer, that call can 403 before the
# policy has propagated.
resource "time_sleep" "terraform_ci_iam_propagation" {
  create_duration = "60s"
  depends_on = [
    google_bigquery_dataset_iam_member.terraform_ci_dataset_admin,
  ]
}
