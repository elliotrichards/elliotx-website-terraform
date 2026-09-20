locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "bigquery.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# A dedicated pool for the main site's repo — separate from
# ../last-fm-now-playing's apps-github-pool, which trusts a different repo
# (elliotx-website-apps). A pool's attribute_condition trusts exactly one
# repo, so a second GitHub repo needing WIF here means a second pool, not a
# shared one.
module "github_oidc_pool" {
  source      = "../modules/github-oidc-pool"
  project_id  = var.project_id
  pool_id     = "website-github-pool"
  provider_id = "website-github-provider"
  github_repo = var.website_github_repo

  depends_on = [google_project_service.this]
}

# Read-only: this SA can query BigQuery, nothing else. No Cloud Run, no
# secrets, no write access anywhere — the data-refresh GitHub Action only
# ever reads scrobbles and writes its output back to git, not GCP.
module "music_data_reader" {
  source      = "../modules/github-ci-service-account"
  project_id  = var.project_id
  pool_name   = module.github_oidc_pool.pool_name
  github_repo = var.website_github_repo

  service_account_id           = "website-music-data-reader"
  service_account_display_name = "Website music-data-refresh reader"

  # bigquery.jobUser has no dataset-scoped equivalent — running a query job
  # at all requires it project-wide. Actual data access is still scoped to
  # just the lastfm dataset via the dataViewer grant below.
  project_role_grants = [
    "roles/bigquery.jobUser",
  ]

  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}

# The dataset is owned by ../last-fm-recent-tracks's state — just granted
# dataViewer here, never recreated.
resource "google_bigquery_dataset_iam_member" "reader" {
  project    = var.project_id
  dataset_id = var.bq_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${module.music_data_reader.service_account_email}"
  depends_on = [google_project_service.this, time_sleep.terraform_ci_iam_propagation]
}
