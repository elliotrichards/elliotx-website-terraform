output "service_uri" { value = one(module.cloud_run[*].uri) }
output "public_films_url" { value = "https://storage.googleapis.com/${google_storage_bucket.stats_public.name}/films.json" }
# Share the watch-log sheet (Viewer) with this address.
output "runner_service_account_email" { value = google_service_account.runner.email }
output "scheduler_service_account_email" { value = google_service_account.scheduler.email }
output "artifact_registry_url" { value = module.artifact_registry.url }
output "ci_service_account_email" { value = module.film_stats_ci.service_account_email }
output "cache_bucket" { value = google_storage_bucket.tmdb_cache.name }
output "scheduler_job_name" { value = one(google_cloud_scheduler_job.daily_run[*].name) }
