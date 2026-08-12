output "name" { value = google_cloudfunctions2_function.this.name }
output "uri" { value = google_cloudfunctions2_function.this.url }
output "source_bucket" { value = google_storage_bucket.source.name }
