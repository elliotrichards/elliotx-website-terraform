output "reader_service_account_email" { value = module.music_data_reader.service_account_email }
output "website_workload_identity_provider" { value = module.github_oidc_pool.provider_name }
