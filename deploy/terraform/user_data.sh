#!/bin/bash
# Runs once, as root, on the instance's first boot (cloud-init). Terraform
# renders ${docker_image} in via templatefile() -- see instance.tf.
#
# Kept deliberately tiny: install Docker, start it, run the container with a
# restart policy so it survives reboots and daemon restarts. Everything else
# (the frontend build, the Python deps) is already baked into the image.
set -euxo pipefail

dnf install -y docker
systemctl enable --now docker

docker run -d \
  --name sudoku \
  --restart unless-stopped \
  -p 80:8000 \
  "${docker_image}"
