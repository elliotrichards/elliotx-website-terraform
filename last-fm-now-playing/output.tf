output "function_uri" { value = module.cloud_function.uri }
output "function_service_account_email" { value = google_service_account.function_runtime.email }
output "artifact_registry_url" { value = module.artifact_registry.url }
output "secret_id" { value = module.secret.secret_id }
output "ci_service_account_email" { value = module.github_ci.service_account_email }
output "ci_workload_identity_provider" { value = module.github_ci.workload_identity_provider }
