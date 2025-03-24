provider "google" {
  project = var.project
  region  = var.region
}

resource "google_compute_network" "vpc_network" {
  name = "${var.prefix}-vpc"
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "${var.prefix}-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

resource "google_compute_firewall" "allow_flask" {
  name    = "${var.prefix}-flask-fw"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.prefix}-ssh-fw"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "flask_vm" {
  name         = "${var.prefix}-flask-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt update
    apt install -y docker.io supervisor

    cat <<EOL > /etc/supervisor/conf.d/flask.conf
    [program:flask]
    command=/usr/bin/docker run -p 5000:5000 us-central1-docker.pkg.dev/${var.project}/my-repo/flask-app:v1
    autostart=true
    autorestart=true
    stderr_logfile=/var/log/flask.err.log
    stdout_logfile=/var/log/flask.out.log
    EOL

    systemctl enable supervisor
    systemctl start supervisor || service supervisor start

    supervisorctl reread
    supervisorctl update
  EOF

  tags = ["flask"]
}
