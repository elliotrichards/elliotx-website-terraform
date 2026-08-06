# CI identity for GitHub Actions (elliotrichards/elliotx-website-terraform) to run
# terraform plan/apply via Workload Identity Federation — no long-lived key.
resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions"
  description               = "Federates GitHub Actions OIDC tokens for elliotx-website-terraform"
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only tokens minted for this exact repo can federate in.
  attribute_condition = "assertion.repository == \"elliotrichards/elliotx-website-terraform\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "terraform_ci" {
  account_id   = "terraform-ci"
  display_name = "Terraform CI (GitHub Actions)"
  project      = var.project_id
}

# Lets workflow runs from this repo impersonate the SA above — scoped to the
# repo via the provider's attribute_condition, not just this binding.
resource "google_service_account_iam_member" "terraform_ci_wif_user" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/elliotrichards/elliotx-website-terraform"
}

# --- Permissions terraform-ci needs to manage everything else in this repo ---

# Covers global addresses, managed SSL certs, backend buckets, url maps,
# target http(s) proxies, and forwarding rules (main.tf).
resource "google_project_iam_member" "terraform_ci_load_balancer_admin" {
  project = var.project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# Project-scoped (not bucket-scoped) because terraform-ci must be able to
# create the static-site bucket itself, plus it covers the tfstate bucket.
resource "google_project_iam_member" "terraform_ci_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# Create/manage the cloud-build-sa resource (iam.tf).
resource "google_project_iam_member" "terraform_ci_service_account_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# Grant/revoke the project-level roles iam.tf assigns to cloud-build-sa.
# Broad by nature (can alter any project IAM binding) — every change to this
# repo, including to this role itself, goes through the PR plan + manual
# apply approval, so a self-granting change is never silent.
resource "google_project_iam_member" "terraform_ci_project_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}
