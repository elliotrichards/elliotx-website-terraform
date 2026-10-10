output "service_uri" { value = one(module.cloud_run[*].uri) }
output "runtime_service_account_email" { value = google_service_account.runtime.email }
output "artifact_registry_url" { value = module.artifact_registry.url }
output "secret_ids" { value = { for env_name, mod in module.secret : env_name => mod.secret_id } }
output "ci_service_account_email" { value = module.contact_form_ci.service_account_email }
