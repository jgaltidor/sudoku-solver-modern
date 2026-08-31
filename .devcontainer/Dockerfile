# Devcontainer base image. Was a bare `"image":` in devcontainer.json until
# Packer needed installing -- Terraform and the AWS CLI come from official
# devcontainer features (see devcontainer.json), but there is no official/
# maintained devcontainer feature for Packer, and HashiCorp's apt repo has no
# suite for this base's Debian release (trixie) yet. So Packer is installed
# here, at image-build time (cached, not re-run on every container start),
# from the same kind of release zip the official `terraform` feature uses.
#
# Keep the tag in sync with what the feature set expects (a devcontainers
# Python image). Bump PACKER_VERSION by hand: https://releases.hashicorp.com/packer/
FROM mcr.microsoft.com/devcontainers/python:3.12

ARG PACKER_VERSION=1.16.0
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${arch}.zip" -o /tmp/packer.zip \
    && unzip -o /tmp/packer.zip -d /usr/local/bin \
    && rm /tmp/packer.zip \
    && chmod +x /usr/local/bin/packer \
    && packer version
