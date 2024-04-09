provider "google" {
	project = var.project_id
}

# Archive the scripts folder
data "archive_file" "scripts" {
	type        = "zip"
	source_dir  = "../scripts/"
	output_path = "../scripts.zip"
}

resource "google_storage_bucket_object" "zip_file" {
	name   = "scripts.zip"
	bucket = "smt-dev"
	source = "../scripts.zip"
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
		sudo apt-get install -y python3 python3-pip
		sudo apt-get install -y docker.io
		sudo apt install unzip

		sudo docker pull mongo:latest

		sudo docker run --name local-mongo --restart=always -d -p 27017:27017 mongo:latest

		wget https://storage.googleapis.com/${google_storage_bucket_object.zip_file.bucket}/${google_storage_bucket_object.zip_file.name}
		unzip ./${google_storage_bucket_object.zip_file.name} -d ./scripts
		cd ./scripts

		sudo pip3 install --no-cache-dir -r requirements.txt
		sudo python3 main.py

	EOF

}