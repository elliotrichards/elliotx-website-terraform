resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = coalesce(var.pool_display_name != "" ? var.pool_display_name : null, var.pool_id)
}

resource "google_iam_workload_identity_pool_provider" "this" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only tokens minted for this exact repo can federate in.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = coalesce(var.service_account_display_name != "" ? var.service_account_display_name : null, var.service_account_id)
}

# Lets workflow runs from this repo impersonate the SA above — scoped to the
# repo via the provider's attribute_condition, not just this binding.
resource "google_service_account_iam_member" "wif_user" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/attribute.repository/${var.github_repo}"
}

resource "google_project_iam_member" "grants" {
  for_each = toset(var.project_role_grants)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.this.email}"
}
