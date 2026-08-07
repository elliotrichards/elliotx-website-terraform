resource "google_service_account" "cloud_build" {
  account_id   = "cloud-build-sa"
  display_name = "Cloud Build Service Account"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "cloud_build_object_admin" {
  bucket = var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

# gcloud storage rsync needs storage.buckets.get to read bucket metadata,
# which objectAdmin does not grant.
resource "google_storage_bucket_iam_member" "cloud_build_bucket_reader" {
  bucket = var.bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_project_iam_member" "cloud_build_log_writer" {
  project    = var.project_id
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${google_service_account.cloud_build.email}"
  depends_on = [google_project_service.cloudresourcemanager]
}

# 3. Grant Compute Load Balancer Admin (For CDN cache invalidation)
resource "google_project_iam_member" "cloud_build_load_balancer_admin" {
  project    = var.project_id
  role       = "roles/compute.loadBalancerAdmin"
  member     = "serviceAccount:${google_service_account.cloud_build.email}"
  depends_on = [google_project_service.cloudresourcemanager]
}
