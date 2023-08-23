provider "google" {
  project = var.project_id
}

locals {
  network_interfaces_map = { for i, n in var.networks : n => {
    network     = n,
    subnetwork  = element(var.sub_networks, i)
    external_ip = element(var.external_ips, i)
    }
  }

  metadata = {
    bitnami-base-password = random_password.password_0.result
    bitnami-db-password = random_password.password_1.result
    optional-password = random_password.password_2.result
    admin-username = admin@local
    user-username = user@local
    some-other-domain-metadata = domain
    install-phpmyadmin = installPhpMyAdmin
    image-caching = imageCaching
    image-compression = imageCompression
    image-sizing = imageSizing
    image-cache-size = imageCacheSize
    cache-expiration-minutes = cacheExpiration
    extra-lb-zone0 = extraLbZone0
    extra-lb-zone1 = extraLbZone1
  }
}

resource "google_compute_instance" "instance" {
  name = "${var.goog_cm_deployment_name}-vm"
  machine_type = var.machine_type
  zone = var.zone

  boot_disk {
    initialize_params {
      size = var.boot_disk_size
      type = var.boot_disk_type
      image = var.source_image
    }
  }

  can_ip_forward = false

  metadata = local.metadata

  dynamic "network_interface" {
    for_each = local.network_interfaces_map
    content {
      network = network_interface.key
      subnetwork = network_interface.value.subnetwork

      dynamic "access_config" {
        for_each = network_interface.value.external_ip == "NONE" ? [] : [1]
        content {
          nat_ip = network_interface.value.external_ip == "EPHEMERAL" ? null : network_interface.value.external_ip
        }
      }
    }
  }

  guest_accelerator {
    type = var.accelerator_type
    count = var.accelerator_count
  }

  scheduling {
    // GPUs do not support live migration
    on_host_maintenance = var.accelerator_count > 0 ? "TERMINATE" : "MIGRATE"
  }
}

resource "google_compute_firewall" tcp_80 {
  count = var.enable_tcp_80 ? 1 : 0

  name = "${var.goog_cm_deployment_name}-tcp-80"
  network = element(var.networks, 0)

  allow {
    ports = ["80"]
    protocol = "tcp"
  }

  source_ranges =  compact([for range in split(",", var.tcp_80_source_ranges) : trimspace(range)])
}

resource "google_compute_firewall" tcp_443 {
  count = var.enable_tcp_443 ? 1 : 0

  name = "${var.goog_cm_deployment_name}-tcp-443"
  network = element(var.networks, 0)

  allow {
    ports = ["443"]
    protocol = "tcp"
  }

  source_ranges =  compact([for range in split(",", var.tcp_443_source_ranges) : trimspace(range)])
}

resource "google_compute_firewall" icmp {
  count = var.enable_icmp ? 1 : 0

  name = "${var.goog_cm_deployment_name}-icmp"
  network = element(var.networks, 0)

  allow {
    protocol = "icmp"
  }

  source_ranges =  compact([for range in split(",", var.icmp_source_ranges) : trimspace(range)])
}

resource "random_password" "password_0" {
  length = 8
  special = false
}

resource "random_password" "password_1" {
  length = 8
  special = false
}

resource "random_password" "password_2" {
  length = 8
  special = false
}
