#! /usr/bin/env bash
# Push the backend/frontend images (see docker-compose.yml's image: keys) and
# the combined single image (see Dockerfile.combined) to Docker Hub. Build
# them first -- this doesn't build, only pushes whatever's already tagged
# locally:
#
#   docker compose build
#   docker build -f Dockerfile.combined -t jgaltidor/sudoku-solver-modern:latest .
#   scripts/publish.sh
#
# Requires `docker login` to jgaltidor's Docker Hub account first.
set -euo pipefail

basedir=$(cd "$(dirname "$0")/.." && pwd)
docker compose -f "$basedir/docker-compose.yml" push
docker push jgaltidor/sudoku-solver-modern:latest
