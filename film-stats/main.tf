locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudscheduler.googleapis.com",
    "storage.googleapis.com",
    "sheets.googleapis.com",
    "monitoring.googleapis.com",
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

# Runtime identity for the deployed service. Reads the sheet because the
# sheet itself is shared with this SA as Viewer (a manual step, outside GCP
# IAM entirely) — no project role, no key file. Everything else is granted
# per-resource below: secretAccessor on its one secret, objectAdmin on its
# two buckets.
resource "google_service_account" "runner" {
  project      = var.project_id
  account_id   = "film-stats-runner"
  display_name = "Film stats Cloud Run runtime"
  depends_on   = [google_project_service.this]
}

module "artifact_registry" {
  source        = "../modules/artifact-registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  format        = "DOCKER"
  description   = "Container images for the film-stats Cloud Run job"

  writer_members = [
    "serviceAccount:${module.film_stats_ci.service_account_email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

module "tmdb_token" {
  source     = "../modules/secret"
  project_id = var.project_id
  secret_id  = var.secret_id

  accessor_members = [
    "serviceAccount:${google_service_account.runner.email}",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# --- Buckets ---

# Trimmed TMDB responses, keyed tmdb/{movie|tv}/{id}.json. Rebuildable (the
# next run just refetches), so no versioning — it only exists to spare TMDB
# and to keep already-seen titles working through a TMDB outage.
resource "google_storage_bucket" "tmdb_cache" {
  project                     = var.project_id
  name                        = "${var.project_id}-film-tmdb-cache"
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket_iam_member" "runner_cache_admin" {
  bucket = google_storage_bucket.tmdb_cache.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runner.email}"
}

# Public on purpose: stats.json is derived from a watch log that's meant to
# be shown on the site anyway (notes are never published — the app drops
# that column on read). allUsers gets read on this bucket only.
resource "google_storage_bucket" "stats_public" {
  project                     = var.project_id
  name                        = "${var.project_id}-film-stats-public"
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  # Only matters for a client-side fetch from the browser; a build-time
  # fetch (the site's usual pattern) isn't subject to CORS at all.
  cors {
    origin          = [var.site_origin]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Cache-Control", "ETag"]
    max_age_seconds = 3600
  }

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket_iam_member" "stats_public_read" {
  bucket = google_storage_bucket.stats_public.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "runner_stats_admin" {
  bucket = google_storage_bucket.stats_public.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runner.email}"
}

# --- Service + schedule ---

module "cloud_run" {
  count       = var.create_service ? 1 : 0
  source      = "../modules/cloud-run-service"
  project_id  = var.project_id
  region      = var.region
  name        = var.service_name
  description = "Reads the film watch-log sheet, enriches it from TMDB, publishes stats.json"

  service_account_email = google_service_account.runner.email
  # Private: only the Scheduler SA below can call this.
  allow_unauthenticated = false

  environment_variables = {
    SHEET_ID     = var.sheet_id
    SHEET_TAB    = var.sheet_tab
    SHEET_RANGE  = var.sheet_range
    CACHE_BUCKET = google_storage_bucket.tmdb_cache.name
    STATS_BUCKET = google_storage_bucket.stats_public.name
    TIME_ZONE    = var.schedule_time_zone
  }
  secret_environment_variables = {
    TMDB_API_TOKEN = module.tmdb_token.secret_id
  }

  memory             = "512Mi"
  timeout            = "120s"
  min_instance_count = 0
  max_instance_count = 1

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# Separate from the runner: this identity can only invoke the service,
# nothing else — and the runner has no run.invoker, so it can't call itself.
resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = "film-stats-scheduler"
  display_name = "Film stats Cloud Scheduler invoker"
  depends_on   = [google_project_service.this]
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  count    = var.create_service ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = module.cloud_run[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "daily_run" {
  count       = var.create_service ? 1 : 0
  project     = var.project_id
  region      = var.region
  name        = "film-stats-daily"
  description = "Rebuilds stats.json from the film watch-log sheet once a day"
  schedule    = var.schedule
  time_zone   = var.schedule_time_zone
  # Just over the service's own 120s timeout, so Scheduler doesn't give up
  # on an attempt Cloud Run is still running.
  attempt_deadline = "150s"

  http_target {
    http_method = "POST"
    uri         = module.cloud_run[0].uri

    oidc_token {
      service_account_email = google_service_account.scheduler.email
      audience              = module.cloud_run[0].uri
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "60s"
    max_backoff_duration = "600s"
    max_doublings        = 3
  }

  depends_on = [
    google_project_service.this,
    time_sleep.terraform_ci_iam_propagation,
    google_cloud_run_v2_service_iam_member.scheduler_invoker,
  ]
}

# --- Alerting ---

resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email != "" ? 1 : 0
  project      = var.project_id
  display_name = "film-stats alerts"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# Scheduler logs every failed attempt (non-2xx from the service, or a
# timeout) at ERROR. The app returns 500 on any unhandled failure, so this
# covers both "the job never ran" and "the job ran and broke". Bad sheet
# rows and TMDB misses are warnings inside stats.json, not failures.
resource "google_monitoring_alert_policy" "run_failed" {
  count        = var.alert_email != "" && var.create_service ? 1 : 0
  project      = var.project_id
  display_name = "film-stats daily run failed"
  combiner     = "OR"

  conditions {
    display_name = "Scheduler attempt failed"
    condition_matched_log {
      filter = join(" AND ", [
        "resource.type=\"cloud_scheduler_job\"",
        "resource.labels.job_id=\"${google_cloud_scheduler_job.daily_run[0].name}\"",
        "severity>=ERROR",
      ])
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]

  # One email per hour at most: a failing day retries up to three more times.
  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
    auto_close = "86400s"
  }

  documentation {
    content   = "The daily film-stats run failed. Check the Cloud Run logs for service ${var.service_name} (look for \"run failed:\")."
    mime_type = "text/markdown"
  }
}
