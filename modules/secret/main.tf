# Secret container only — no google_secret_manager_secret_version here.
# The value is populated out-of-band (`gcloud secrets versions add`, or CI)
# so the API key never lands in Terraform state or this repo.
resource "google_secret_manager_secret" "this" {
  project   = var.project_id
  secret_id = var.secret_id
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  # Keyed by index, not toset(var.accessor_members): members are often SA
  # emails not known until apply, and for_each requires its *keys* known at
  # plan time even if values aren't — a list index is known, the member
  # string may not be.
  for_each  = { for idx, member in var.accessor_members : idx => member }
  project   = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}

resource "google_secret_manager_secret_iam_member" "version_manager" {
  for_each  = { for idx, member in var.version_manager_members : idx => member }
  project   = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretVersionManager"
  member    = each.value
}
