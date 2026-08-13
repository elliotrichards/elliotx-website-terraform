resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = coalesce(var.service_account_display_name != "" ? var.service_account_display_name : null, var.service_account_id)
}

# Lets workflow runs from this repo impersonate the SA above — scoped to the
# repo via the pool's own provider condition, not just this binding. Multiple
# apps' service accounts can each bind to the same shared pool this way.
resource "google_service_account_iam_member" "wif_user" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.pool_name}/attribute.repository/${var.github_repo}"
}

resource "google_project_iam_member" "grants" {
  for_each = toset(var.project_role_grants)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.this.email}"
}
