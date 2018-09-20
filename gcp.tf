variable "user" {
  type = "string"
  description = "Your name (ex: holysugar)"
}

variable "basename" {
  type = "string"
  description = "resource prefix"
}

variable "gcp_project" {
  type ="string"
  description = "GCP project ID"
}

variable "gcp_region" {
  type ="string"
  description = "region create resource in"
}

variable "cert_url" {
  type ="string"
  description = "HTTPS cert url"
}

variable "iap_client_id" {
  type = "string"
}

variable "iap_client_secret" {
  type = "string"
}

provider "google" {
  credentials = "${file("account.json")}"
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

resource "google_compute_network" "iaptrial" {
  name = "${var.basename}-network"
}

resource "google_compute_firewall" "iaptrial-icmp" {
  name    = "${var.basename}-firewall-icmp"
  network = "${var.basename}-network"
  allow { protocol = "icmp" }
  priority = 65534
}

resource "google_compute_global_address" "iaptrial" {
  name    = "${var.basename}-addr"
}

resource "google_compute_instance_template" "iaptrial" {
  name = "${var.basename}-template"
  description = "IAP load balancer example"

  tags = ["${var.basename}-rackserver"]

  labels = {
    author = "${var.user}"
  }

  machine_type = "g1-small"
  can_ip_forward = false

  scheduling {
    automatic_restart = false
    preemptible = true
  }

  disk {
    source_image = "debian-9-stretch-v20180820"
    auto_delete = true
    boot = true
    disk_size_gb = 10
  }

  network_interface {
    network = "${var.basename}-network"
    access_config {
    }
  }

/*
  metadata_startup_script = <<EOF
    apt install -y git nginx
EOF
*/

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}

resource "google_compute_health_check" "iaptrial" {
  name                = "${var.basename}-healthz"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  http_health_check {
    request_path = "/healthz"
    port         = "80"
  }
}

resource "google_compute_instance_group_manager" "iaptrial" {
  name = "${var.basename}-igm"
  base_instance_name = "${var.basename}"
  instance_template = "${google_compute_instance_template.iaptrial.self_link}"
  zone = "asia-northeast1-b"
  target_size = "1"

  named_port {
    name = "httpport"
    port = 80
  }
}

resource "google_compute_backend_service" "iaptrial" {
  name          = "${var.basename}-backend"
  port_name     = "rackport"
  protocol      = "HTTP"
  backend {
    group = "${google_compute_instance_group_manager.iaptrial.instance_group}"
  }
  health_checks = ["${google_compute_health_check.iaptrial.self_link}"]

  iap {
    oauth2_client_id = "${var.iap_client_id}"
    oauth2_client_secret = "${var.iap_client_secret}"
  }
}

resource "google_compute_url_map" "iaptrial" {
  name            = "${var.basename}-urlmap"
  default_service = "${google_compute_backend_service.iaptrial.self_link}"
}

resource "google_compute_target_https_proxy" "iaptrial" {
  name        = "${var.basename}-proxy"
  url_map     = "${google_compute_url_map.iaptrial.self_link}"
  ssl_certificates = ["${var.cert_url}"]
}

resource "google_compute_global_forwarding_rule" "iaptrial" {
  name        = "${var.basename}-https-rule"
  target      = "${google_compute_target_https_proxy.iaptrial.self_link}"
  ip_address  = "${google_compute_global_address.iaptrial.address}"
  port_range  = "443-443"
}

resource "google_compute_firewall" "iaptrial-http" {
  name    = "${var.basename}-firewall-http"
  network = "${var.basename}-network"
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
  target_tags = ["${var.basename}-rackserver"]
}

resource "google_compute_firewall" "iaptrial-ssh" {
  name    = "${var.basename}-firewall-ssh"
  network = "${var.basename}-network"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  priority = 65534
}


output "ip" {
  value = "${google_compute_global_forwarding_rule.iaptrial.ip_address}"
}

