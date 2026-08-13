output "service_uri" { value = module.cloud_run.uri }
output "runtime_service_account_email" { value = google_service_account.function_runtime.email }
output "artifact_registry_url" { value = module.artifact_registry.url }
output "secret_id" { value = module.secret.secret_id }
output "ci_service_account_email" { value = module.now_playing_ci.service_account_email }
output "apps_workload_identity_provider" { value = module.github_oidc_pool.provider_name }
