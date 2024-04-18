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

data "cloudinit_config" "user_data" {

  for_each = var.locations

  gzip          = false
  base64_encode = false

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"

    content = templatefile("cloud-init/init-vm.yml", {
      app_name : var.app_name,

      bacalhau_service : filebase64("${path.root}/node_files/bacalhau.service"),
	  poller_service : filebase64("${path.root}/node_files/poller.service"),
      ipfs_service : base64encode(file("${path.module}/node_files/ipfs.service")),
      start_bacalhau : filebase64("${path.root}/node_files/start_bacalhau.sh"),

	  scripts_bucket_source: "${google_storage_bucket_object.zip_file.bucket}",
	  scripts_object_key : "${google_storage_bucket_object.zip_file.name}",
      # Need to do the below to remove spaces and newlines from public key
      ssh_key : compact(split("\n", file(var.public_key)))[0],

      node_name : "${var.app_tag}-${each.key}-vm",
      username : var.username,
      region : each.value.region,
      zone : each.key,
      project_id : var.project_id,
    })
  }
}

resource "google_compute_instance" "my_instance" {
	for_each = var.locations
	# for_each = { for k, v in var.locations : k => v if k == var.bootstrap_zone }
	# for_each = { for k, v in var.locations : k => v if k == var.bootstrap_zone }

	# for_each = {
	# 	for key, value in var.locations :
	# 	key => value if key != var.bootstrap_zone
	# }

	# Your resource configuration...

	# Execute a local command to print out the key
	provisioner "local-exec" {
		command = "echo 'Non-bootstrapped instance key: ${each.key}'"
	}

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

	metadata = {
		user-data = "${data.cloudinit_config.user_data[each.key].rendered}",
		ssh-keys  = "${var.username}:${file(var.public_key)}",
	}

	/*metadata_startup_script = <<-EOF
		#!/bin/bash

		# Update package list and install necessary packages
		apt-get update -y
		apt-get install -y python3 python3-pip docker.io unzip

		curl -sL https://get.bacalhau.org/install.sh | bash

		bacalhau serve

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

	EOF*/

}


resource "null_resource" "configure_requester_node" {
  // Only run this on the bootstrap node
  for_each = { for k, v in google_compute_instance.my_instance : k => v if v.zone == var.bootstrap_zone }

  depends_on = [google_compute_instance.my_instance]

  connection {
    host        = each.value.network_interface[0].access_config[0].nat_ip
    port        = 22
    user        = var.username
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSHD is now alive.'",
      "echo 'Hello, world.'",
	  "sudo timeout 600 bash -c 'until [[ -s /data/bacalhau.run ]]; do sleep 1; done' && echo 'Bacalhau is now alive.'",
    ]
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.username}@${each.value.network_interface[0].access_config[0].nat_ip} 'sudo cat /data/bacalhau.run' > ${var.bacalhau_run_file}"
  }
}