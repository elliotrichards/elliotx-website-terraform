# --- Variables ---
output "load_balancer_ip" { value = google_compute_global_address.lb_static_ip.address }

# --- CI (used to wire up .github/workflows/terraform.yml) ---
output "terraform_ci_service_account_email" { value = google_service_account.terraform_ci.email }
output "terraform_ci_workload_identity_provider" { value = google_iam_workload_identity_pool_provider.github_actions.name }
