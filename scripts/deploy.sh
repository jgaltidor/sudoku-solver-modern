#! /usr/bin/env bash
# Deploy the combined production image to the AWS EC2 environment defined in
# deploy/terraform/. Two steps:
#
#   1. build the linux/amd64 image from the current tree and push it to Docker Hub
#   2. terraform apply  (creates the instance, or rolls out a new image to it)
#
# Full walkthrough, prerequisites (IAM user, `aws configure`, `docker login`,
# terraform.tfvars), and teardown: deploy/README.md
#
#   scripts/deploy.sh                 # build+push, then terraform apply
#   scripts/deploy.sh --skip-image    # just terraform apply (image already current)
#   scripts/deploy.sh --plan          # build+push, then terraform plan (no apply)
#
# Needs: docker (with buildx + `docker login`), terraform, aws credentials.
set -euo pipefail

basedir=$(cd "$(dirname "$0")/.." && pwd)
image="${DEPLOY_IMAGE:-jgaltidor/sudoku-solver-modern:latest}"
platform="${DEPLOY_PLATFORM:-linux/amd64}" # match the instance's arch (t3.* = amd64)

skip_image=false
tf_cmd=(apply)
for arg in "$@"; do
  case "$arg" in
    --skip-image) skip_image=true ;;
    --plan) tf_cmd=(plan) ;;
    -h | --help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [ "$skip_image" = false ]; then
  echo ">> building and pushing $image ($platform)"
  docker buildx build --platform "$platform" \
    -f "$basedir/Dockerfile.combined" -t "$image" --push "$basedir"
fi

echo ">> terraform ${tf_cmd[*]}"
terraform -chdir="$basedir/deploy/terraform" init -input=false
terraform -chdir="$basedir/deploy/terraform" "${tf_cmd[@]}"

if [ "${tf_cmd[0]}" = "apply" ]; then
  echo
  terraform -chdir="$basedir/deploy/terraform" output
fi
