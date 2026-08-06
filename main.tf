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

resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_bucket.static_backend.id
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
