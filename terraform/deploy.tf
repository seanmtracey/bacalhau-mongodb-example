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
		ports    = ["80", "443", "1234", "4222", "27017"]
	}

	source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "my_instance" {
	for_each = var.locations

	name         = "${var.app_name}-${each.key}"
	machine_type = "${var.machine_type}"
	zone         = "${each.key}"

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

		# Update package list and install necessary packages
		apt-get update -y
		apt-get install -y python3 python3-pip docker.io unzip

		# Pull MongoDB Docker image
		docker pull mongo:latest

		# Run MongoDB container
		docker run --name local-mongo --restart=always -d -p 27017:27017 -v mongo_data:/data/db mongo:latest

		# Download and extract files
		wget https://storage.googleapis.com/${google_storage_bucket_object.zip_file.bucket}/${google_storage_bucket_object.zip_file.name}
		unzip ./${google_storage_bucket_object.zip_file.name} -d ./scripts
		cd ./scripts

		# Install Python dependencies
		pip3 install --no-cache-dir -r requirements.txt

		# Create systemd service file
		echo -e '[Unit]\nDescription=The system poller for use with MongoDB\nAfter=network.target\n\n[Service]\nType=simple\nExecStart=/usr/bin/python3 /scripts/main.py\nRestart=always\n\n[Install]\nWantedBy=multi-user.target' > ~/poller.service

		# Move systemd service file to appropriate directory
		sudo mv ~/poller.service /etc/systemd/system/

		# Reload systemd daemon
		sudo systemctl daemon-reload

		# Enable and start the systemd service
		sudo systemctl enable poller.service
		sudo systemctl start poller.service

		# Enable Docker service
		sudo systemctl enable docker.service

		curl -sL https://get.bacalhau.org/install.sh | bash


	EOF

}
