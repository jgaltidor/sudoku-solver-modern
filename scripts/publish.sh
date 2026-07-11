#! /usr/bin/env bash
# Push the backend/frontend images (see docker-compose.yml's image: keys) to
# Docker Hub. Build them first -- this doesn't build, only pushes whatever's
# already tagged locally:
#
#   docker compose build
#   scripts/publish.sh
#
# Requires `docker login` to jgaltidor's Docker Hub account first.
set -euo pipefail

basedir=$(cd "$(dirname "$0")/.." && pwd)
docker compose -f "$basedir/docker-compose.yml" push
