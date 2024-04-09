provider "google" {
  project = var.project_id
}

resource "google_compute_firewall" "http" {
  name    = "allow-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "27017"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "my_instance" {
  name         = "mongodb-test"
  machine_type = "e2-small"
  zone         = "europe-west2-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size = 20
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y docker.io
    sudo docker pull mongo:latest
    sudo docker pull seanmtracey/smt-mongo-poll:linux_amd64
    sudo docker run --name local-mongo --restart=always -d -p 27017:27017 mongo:latest
    sudo docker run -d --name poller --network="host" seanmtracey/smt-mongo-poll:linux_amd64

    # sudo docker run --name local-mongo --restart=always -d -p 27017:27017 mongo:latest
    # sudo docker run -d --restart=always -e MONGO_ADDR=your_mongo_host -e MONGO_PORT=your_mongo_port your_docker_image_name
  EOF
}