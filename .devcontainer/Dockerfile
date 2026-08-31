# Devcontainer base image. Was a bare `"image":` in devcontainer.json until the
# deploy tooling landed. Terraform and the AWS CLI come from official
# devcontainer features (see devcontainer.json); the things below have no
# maintained feature, so they're installed here at image-build time (cached,
# not re-run on every container start):
#
#   - Packer          -- HashiCorp's apt repo has no suite for this base's
#                        Debian release (trixie); install the release zip, the
#                        same way the official `terraform` feature does.
#   - session-manager-plugin -- required by `aws ssm start-session`, which is
#                        how you get a shell on the deployed EC2 instance
#                        (deploy/ uses SSM, not SSH). AWS ships it only as a
#                        distro package, not via the aws-cli feature.
#   - shellcheck       -- backs the timonwong.shellcheck extension and is the
#                        linter used on scripts/*.sh; from Debian apt.
#
# Keep the tag in sync with what the feature set expects (a devcontainers
# Python image). Bump PACKER_VERSION by hand: https://releases.hashicorp.com/packer/
FROM mcr.microsoft.com/devcontainers/python:3.12

RUN apt-get update \
    && apt-get install -y --no-install-recommends shellcheck \
    && rm -rf /var/lib/apt/lists/* \
    && shellcheck --version

ARG PACKER_VERSION=1.16.0
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${arch}.zip" -o /tmp/packer.zip \
    && unzip -o /tmp/packer.zip -d /usr/local/bin \
    && rm /tmp/packer.zip \
    && chmod +x /usr/local/bin/packer \
    && packer version

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
    amd64) smp_dir=ubuntu_64bit ;; \
    arm64) smp_dir=ubuntu_arm64 ;; \
    *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${smp_dir}/session-manager-plugin.deb" -o /tmp/smp.deb \
    && dpkg -i /tmp/smp.deb \
    && rm /tmp/smp.deb \
    && session-manager-plugin --version
