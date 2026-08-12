resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  format        = var.format
  description   = var.description
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  # Keyed by index, not toset(var.writer_members): members are often SA
  # emails not known until apply (e.g. a sibling module's service account),
  # and for_each requires its *keys* to be known at plan time even if values
  # aren't — a list index is known, the member string may not be.
  for_each   = { for idx, member in var.writer_members : idx => member }
  project    = google_artifact_registry_repository.this.project
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.repository_id
  role       = "roles/artifactregistry.writer"
  member     = each.value
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each   = { for idx, member in var.reader_members : idx => member }
  project    = google_artifact_registry_repository.this.project
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.repository_id
  role       = "roles/artifactregistry.reader"
  member     = each.value
}
