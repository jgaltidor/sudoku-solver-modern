#! /usr/bin/env bash
# Lifecycle wrapper for the AWS EC2 environment defined in deploy/terraform/.
# Full walkthrough / prerequisites (IAM user, `aws configure`, `docker login`,
# S3 state bucket): deploy/README.md
#
#   scripts/deploy.sh [deploy]        build+push the linux/amd64 image, then `terraform apply`
#   scripts/deploy.sh deploy --skip-image   skip the image build (image already current)
#   scripts/deploy.sh deploy --plan         build+push, then `terraform plan` (no apply)
#   scripts/deploy.sh stop            aws ec2 stop-instances  (pause compute billing; disk stays)
#   scripts/deploy.sh start           aws ec2 start-instances (instance gets a new public IP)
#   scripts/deploy.sh destroy         terraform destroy       (removes everything, ~$0)
#
# Needs: terraform + aws credentials (plus docker w/ buildx + `docker login`
# for the image build).
set -euo pipefail

basedir=$(cd "$(dirname "$0")/.." && pwd)
tfdir="$basedir/deploy/terraform"
image="${DEPLOY_IMAGE:-jgaltidor/sudoku-solver-modern:latest}"
platform="${DEPLOY_PLATFORM:-linux/amd64}" # match the instance's arch (t3.* = amd64)

tf() { terraform -chdir="$tfdir" "$@"; }
instance_id() { tf output -raw instance_id; }

# Every subcommand touches remote (S3) state, so it must be initialized first --
# and .terraform/ is gitignored, so a fresh checkout or a rebuilt devcontainer
# has none. Idempotent + quiet once initialized. Not -migrate-state: converting
# a pre-existing *local* state to S3 is a deliberate one-off (see backend.tf and
# "Migrating an existing deployment" in deploy/README.md).
tf_init() { tf init -input=false >/dev/null; }

usage() { sed -n '2,14p' "$0"; }

cmd="${1:-deploy}"
[ $# -gt 0 ] && shift || true

case "$cmd" in
  -h | --help | help)
    usage
    ;;

  deploy)
    skip_image=false
    tf_action=apply
    for arg in "$@"; do
      case "$arg" in
        --skip-image) skip_image=true ;;
        --plan) tf_action=plan ;;
        *) echo "deploy: unknown option $arg" >&2; exit 2 ;;
      esac
    done

    if [ "$skip_image" = false ]; then
      echo ">> building and pushing $image ($platform)"
      docker buildx build --platform "$platform" \
        -f "$basedir/Dockerfile.combined" -t "$image" --push "$basedir"
    fi

    echo ">> terraform $tf_action"
    tf_init
    tf "$tf_action"
    [ "$tf_action" = apply ] && { echo; tf output; }
    ;;

  stop)
    tf_init
    id=$(instance_id)
    echo ">> stopping $id"
    aws ec2 stop-instances --instance-ids "$id" --query 'StoppingInstances[].CurrentState.Name' --output text
    echo "compute billing stops once it reaches 'stopped'; the EBS volume still costs ~\$0.65/mo."
    ;;

  start)
    tf_init
    id=$(instance_id)
    echo ">> starting $id"
    aws ec2 start-instances --instance-ids "$id" --query 'StartingInstances[].CurrentState.Name' --output text
    echo ">> waiting for it to run..."
    aws ec2 wait instance-running --instance-ids "$id"
    tf refresh >/dev/null
    echo "new address: $(tf output -raw app_url)"
    ;;

  destroy)
    echo ">> terraform destroy"
    tf_init
    tf destroy
    ;;

  *)
    echo "unknown command: $cmd" >&2
    usage
    exit 2
    ;;
esac
