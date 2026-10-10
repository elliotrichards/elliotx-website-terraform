# 1. Static Global IP & GCS Bucket Configuration
resource "google_compute_global_address" "lb_static_ip" {
  name       = "lb-static-ip"
  ip_version = "IPV4"
}


# 2. Managed SSL and Load Balancer
resource "google_compute_managed_ssl_certificate" "lb_cert" {
  name = "lb-managed-ssl-cert"
  managed { domains = [var.domain_name] }
}

resource "google_compute_backend_bucket" "static_backend" {
  name        = "static-backend-bucket"
  bucket_name = google_storage_bucket.static_site.name
  enable_cdn  = true
}

# elliotx.com/api/contact -> the contact form's Cloud Run service (its own
# state in ./website-contact-form). Routed through this load balancer so the
# form posts same-origin: no CORS, and the service's ingress can refuse
# direct *.run.app traffic. Gated on var.contact_form_enabled because the
# service is created in a second step (see website-contact-form/variables.tf).
resource "google_compute_region_network_endpoint_group" "contact_form" {
  count                 = var.contact_form_enabled ? 1 : 0
  name                  = "contact-form-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = var.contact_form_service_name
  }
}

resource "google_compute_backend_service" "contact_form" {
  count      = var.contact_form_enabled ? 1 : 0
  name       = "contact-form-backend"
  protocol   = "HTTPS"
  enable_cdn = false

  backend {
    group = google_compute_region_network_endpoint_group.contact_form[0].id
  }
}

resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_bucket.static_backend.id

  dynamic "host_rule" {
    for_each = var.contact_form_enabled ? [1] : []
    content {
      hosts        = ["*"]
      path_matcher = "site"
    }
  }

  dynamic "path_matcher" {
    for_each = var.contact_form_enabled ? [1] : []
    content {
      name            = "site"
      default_service = google_compute_backend_bucket.static_backend.id

      path_rule {
        paths   = ["/api/contact"]
        service = google_compute_backend_service.contact_form[0].id
      }
    }
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_cert.id]
}

resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name       = "https-forwarding-rule"
  ip_address = google_compute_global_address.lb_static_ip.address
  target     = google_compute_target_https_proxy.https_proxy.id
  port_range = "443"
}

# 1. URL Map for HTTP to HTTPS Redirection
resource "google_compute_url_map" "http_redirect" {
  name = "http-redirect-map"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT" # Issues a 301 Redirect
    strip_query            = false
  }
}

# 2. Target HTTP Proxy for Redirection
resource "google_compute_target_http_proxy" "http_redirect_proxy" {
  name    = "http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

# 3. Global Forwarding Rule for Port 80 (HTTP)
resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "http-forwarding-rule"
  ip_address = google_compute_global_address.lb_static_ip.address
  target     = google_compute_target_http_proxy.http_redirect_proxy.id
  port_range = "80"
}
