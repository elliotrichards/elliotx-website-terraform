output "service_account_email" { value = google_service_account.this.email }
output "service_account_name" { value = google_service_account.this.name }
output "workload_identity_provider" { value = google_iam_workload_identity_pool_provider.this.name }
output "pool_id" { value = google_iam_workload_identity_pool.this.workload_identity_pool_id }
