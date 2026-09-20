locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "bigquery.googleapis.com",
    "cloudscheduler.googleapis.com",
  ]

  # ../last-fm-now-playing created this pool (it was the first app) — its
  # own state owns the resource, so it's addressed here by its deterministic
  # resource name rather than a cross-state data source.
  github_oidc_pool_name = "projects/${var.project_number}/locations/global/workloadIdentityPools/apps-github-pool"
}

resource "google_project_service" "this" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Runtime identity for the deployed service — granted secretAccessor on the
# shared last.fm secret (below) and dataEditor on its own BigQuery dataset
# (below), nothing project-wide.
resource "google_service_account" "function_runtime" {
  project      = var.project_id
  account_id   = "lastfm-recent-tracks-fn"
  display_name = "RecentTracks Cloud Run runtime"
  depends_on   = [google_project_service.this]
}

module "artifact_registry" {
  source        = "../modules/artifact-registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  format        = "DOCKER"
  description   = "Container images for the RecentTracks (last.fm) Cloud Run job"

  writer_members = [
    "serviceAccount:${module.recent_tracks_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# The secret container is owned by ../last-fm-now-playing's state (same
# last.fm API key, reused rather than duplicated) — this only grants this
# app's runtime SA accessor on it, never recreates it.
resource "google_secret_manager_secret_iam_member" "api_key_accessor" {
  project    = var.project_id
  secret_id  = var.secret_id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.function_runtime.email}"
  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

resource "google_bigquery_dataset" "lastfm" {
  project    = var.project_id
  dataset_id = var.bq_dataset_id
  location   = var.bq_location

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

resource "google_bigquery_table" "recent_tracks" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.lastfm.dataset_id
  table_id   = var.bq_table_id

  time_partitioning {
    type  = "DAY"
    field = "scrobble_datetime"
  }

  schema = jsonencode([
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED", description = "When this row was written by the job" },
    { name = "scrobble_uts", type = "INTEGER", mode = "REQUIRED" },
    { name = "scrobble_datetime", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "rank", type = "INTEGER", mode = "REQUIRED", description = "Position within that day's run, 1-indexed" },
    { name = "artist_name", type = "STRING", mode = "REQUIRED" },
    { name = "track_name", type = "STRING", mode = "REQUIRED" },
    { name = "album_name", type = "STRING", mode = "NULLABLE" },
    { name = "artist_mbid", type = "STRING", mode = "NULLABLE" },
    { name = "track_mbid", type = "STRING", mode = "NULLABLE" },
    { name = "album_mbid", type = "STRING", mode = "NULLABLE" },
    { name = "url", type = "STRING", mode = "NULLABLE" },
  ])

  # Every run only ever appends yesterday's scrobbles — never overwritten,
  # so a stray schema-incompatible deploy can't silently wipe history.
  deletion_protection = true
}

resource "google_bigquery_dataset_iam_member" "runtime_data_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.lastfm.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.function_runtime.email}"
}

module "cloud_run" {
  source      = "../modules/cloud-run-service"
  project_id  = var.project_id
  region      = var.region
  name        = var.service_name
  description = "Pulls yesterday's last.fm scrobbles and appends them to BigQuery"

  service_account_email = google_service_account.function_runtime.email
  # Private: only the Scheduler invoker SA below can call this, not the
  # public internet — unlike now-playing, there's no browser widget hitting
  # this route.
  allow_unauthenticated = false

  environment_variables = {
    LASTFM_USERNAME = var.lastfm_username
    BQ_DATASET      = google_bigquery_dataset.lastfm.dataset_id
    BQ_TABLE        = google_bigquery_table.recent_tracks.table_id
  }
  secret_environment_variables = {
    LASTFM_API_KEY = var.secret_id
  }

  min_instance_count = 0
  max_instance_count = 1

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# Separate from the runtime SA: this identity can only invoke the service,
# nothing else — the runtime SA can read the secret/write BigQuery but has
# no run.invoker grant, so it can't be used to call the service itself.
resource "google_service_account" "scheduler_invoker" {
  project      = var.project_id
  account_id   = "lastfm-recent-tracks-invoker"
  display_name = "RecentTracks Cloud Scheduler invoker"
  depends_on   = [google_project_service.this]
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = var.service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_invoker.email}"

  depends_on = [module.cloud_run]
}

resource "google_cloud_scheduler_job" "daily_pull" {
  project     = var.project_id
  region      = var.region
  name        = "lastfm-recent-tracks-daily"
  description = "Triggers the last.fm recent-tracks pull once a day"
  schedule    = var.schedule
  time_zone   = var.schedule_time_zone

  http_target {
    http_method = "POST"
    uri         = module.cloud_run.uri

    oidc_token {
      service_account_email = google_service_account.scheduler_invoker.email
      audience              = module.cloud_run.uri
    }
  }

  retry_config {
    retry_count = 3
  }

  depends_on = [
    google_project_service.this,
    time_sleep.terraform_ci_iam_propagation,
    google_cloud_run_v2_service_iam_member.scheduler_invoker,
  ]
}
