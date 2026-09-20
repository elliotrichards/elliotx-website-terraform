output "service_uri" { value = module.cloud_run.uri }
output "runtime_service_account_email" { value = google_service_account.function_runtime.email }
output "scheduler_invoker_service_account_email" { value = google_service_account.scheduler_invoker.email }
output "artifact_registry_url" { value = module.artifact_registry.url }
output "ci_service_account_email" { value = module.recent_tracks_ci.service_account_email }
output "bq_dataset_id" { value = google_bigquery_dataset.lastfm.dataset_id }
output "bq_table_id" { value = google_bigquery_table.recent_tracks.table_id }
output "scheduler_job_name" { value = google_cloud_scheduler_job.daily_pull.name }
