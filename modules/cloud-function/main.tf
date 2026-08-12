terraform {
  required_providers {
    archive = {
      source = "hashicorp/archive"
    }
  }
}

# Holds the function's deployable source zip. Terraform only ever uploads the
# placeholder below — CI (GitHub Actions -> Cloud Build) manages real deploys
# out-of-band, see the lifecycle block on google_cloudfunctions2_function.
resource "google_storage_bucket" "source" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.name}-source"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# A minimal buildable source so the first `terraform apply` (which performs a
# real Cloud Build) succeeds before any application code exists. The export
# name must match var.entry_point or the build fails, hence templatefile().
data "archive_file" "placeholder_source" {
  type        = "zip"
  output_path = "${path.module}/${var.name}-placeholder-source.zip"

  source {
    content  = templatefile("${path.module}/function-source/index.js.tpl", { entry_point = var.entry_point })
    filename = "index.js"
  }

  source {
    content  = file("${path.module}/function-source/package.json")
    filename = "package.json"
  }
}

resource "google_storage_bucket_object" "placeholder_source" {
  # A static name, not one derived from output_md5: the archive provider
  # doesn't produce byte-identical zips across runs for inline `source`
  # content blocks (it embeds a timestamp), so an md5-derived name would
  # force a replace on every single plan/apply forever. This object is
  # bootstrap-only anyway — ignore_changes below means it's never touched
  # again after the first successful create.
  name   = "source/placeholder.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.placeholder_source.output_path

  lifecycle {
    ignore_changes = all
  }
}

resource "google_cloudfunctions2_function" "this" {
  project     = var.project_id
  name        = var.name
  location    = var.region
  description = var.description

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.placeholder_source.name
      }
    }
  }

  service_config {
    available_memory      = var.available_memory
    timeout_seconds       = var.timeout_seconds
    min_instance_count    = var.min_instance_count
    max_instance_count    = var.max_instance_count
    service_account_email = var.service_account_email
    ingress_settings      = "ALLOW_ALL"
    environment_variables = var.environment_variables
  }

  # CI deploys real code straight to the function/Cloud Build, outside
  # Terraform — without this, the next `terraform plan` would try to revert
  # every CI deploy back to the placeholder source.
  lifecycle {
    ignore_changes = [build_config[0].source]
  }
}

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  count          = var.allow_unauthenticated ? 1 : 0
  project        = google_cloudfunctions2_function.this.project
  location       = google_cloudfunctions2_function.this.location
  cloud_function = google_cloudfunctions2_function.this.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

# Gen2 functions run on Cloud Run under the hood — public HTTP invocation
# also requires the invoker role at the backing Cloud Run service level.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = google_cloudfunctions2_function.this.project
  location = google_cloudfunctions2_function.this.location
  name     = google_cloudfunctions2_function.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
