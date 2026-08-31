# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
History before this file starts is in the git log.

## [Unreleased]

### Added

- **AWS EC2 deployment** (`deploy/`). Terraform provisions one instance in the
  default VPC; `user_data.sh` installs Docker at boot and runs the
  `Dockerfile.combined` image on port 80. Optional Packer template
  (`deploy/packer/`) bakes a Docker-preinstalled AMI. Full walkthrough in
  `deploy/README.md`; least-privilege IAM policy in `deploy/iam-policy.json`.
- `scripts/deploy.sh` — build + push the production image, then `terraform apply`.
- CI `deploy-lint` job: `terraform fmt`/`validate` + `packer fmt`/`validate` on
  `deploy/` (no AWS credentials needed).
- Devcontainer now carries `terraform`, `packer`, `aws`, and `tflint`
  (`.devcontainer/Dockerfile` added for Packer; `terraform` + `aws-cli` as
  official features). `~/.aws` is a named volume so `aws configure` persists
  across rebuilds.
- This changelog.

### Changed

- `.devcontainer/` switched from a bare `image:` to a `Dockerfile` build.
