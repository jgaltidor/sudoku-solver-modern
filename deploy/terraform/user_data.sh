#!/bin/bash
# Runs once, as root, on the instance's first boot (cloud-init). Terraform
# renders ${docker_image} in via templatefile() -- see instance.tf.
#
# shellcheck disable=SC2154  # ${docker_image} is a templatefile() var, not shell
#
# Kept deliberately tiny: install Docker, start it, run the container with a
# restart policy so it survives reboots and daemon restarts. Everything else
# (the frontend build, the Python deps) is already baked into the image.
set -euxo pipefail

dnf install -y docker
systemctl enable --now docker

# Shell access is via SSM Session Manager, which lands you as `ssm-user` with
# passwordless sudo -- so the debug/update commands in deploy/README.md use
# `sudo docker`. No docker group membership to set up (no interactive login).

# Retry the pull -- a transient Docker Hub hiccup during first boot would
# otherwise abort this script (set -e) before the container is ever created,
# and --restart cannot recover a container that does not exist.
for attempt in 1 2 3 4 5; do
  docker pull "${docker_image}" && break
  echo "docker pull attempt $attempt failed; retrying in 15s" >&2
  sleep 15
done

docker run -d \
  --name sudoku \
  --restart unless-stopped \
  -p 80:8000 \
  "${docker_image}"
