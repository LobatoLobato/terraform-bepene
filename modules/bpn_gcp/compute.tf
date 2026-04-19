data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

resource "google_compute_address" "static" {
  name         = "bepene-${var.subdomain}-ip"
  region       = var.gcp_region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_compute_firewall" "vpn" {
  name    = "bepene-${var.subdomain}-wireguard"
  network = "default"

  allow {
    protocol = "udp"
    ports    = [tostring(var.vpn_server_port), "7777"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bepene-vpn"]
}

resource "google_compute_instance" "instance" {
  name         = "bepene-${var.subdomain}"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  tags = ["bepene-vpn"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip       = google_compute_address.static.address
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${var.public_key}"
  }

  metadata_startup_script = templatefile("${path.root}/setup.tpl", {
    domain = local.full_domain
    port   = var.vpn_server_port
    iface  = "ens4"
  })
}
