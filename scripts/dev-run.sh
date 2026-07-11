#! /usr/bin/env bash
# (Re)starts the backend/frontend containers without an image rebuild --
# mirrors the old repo's scripts/dev-run.sh, but intentionally skips its
# "restart backend" step: that existed there to trigger an OCaml recompile
# (omake) inside the container on every restart, which this repo has no
# equivalent of. docker-compose.yml already bind-mounts src/ and frontend/,
# with uvicorn --reload / Vite HMR reloading live on their own, so ordinary
# source edits need no restart at all, let alone a rebuild.
#
# Run `docker compose build` (or the plain `docker compose up --build`) by
# hand first instead if you've changed a dependency (pyproject.toml/uv.lock,
# frontend/package.json) or a Dockerfile -- this script deliberately doesn't
# rebuild on its own, so it won't pick those up.
#
# Like plain `docker compose` itself, this only works from a host terminal,
# not from inside the devcontainer's own terminal (see scripts/run.sh's
# header comment for why); use scripts/run.sh there instead.
#
#   scripts/dev-run.sh
set -euo pipefail

basedir=$(cd "$(dirname "$0")/.." && pwd)
cd "$basedir"

docker compose up -d
