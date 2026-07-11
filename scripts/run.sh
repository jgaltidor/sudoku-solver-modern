#! /usr/bin/env bash
# Launches the backend (uvicorn --reload) and frontend (Vite dev server) as
# native processes -- the devcontainer dev-loop equivalent of
# `docker compose up --build`, which doesn't work *from inside* the
# devcontainer itself: its docker-outside-of-docker feature talks to the
# *host's* Docker daemon over the bind-mounted socket, so a compose bind
# mount like `./src:/app/src` resolves against the devcontainer's own
# filesystem path (/workspaces/...), which the host daemon has never heard
# of -- surfacing as Docker Desktop's "mounts denied" error. Both Python (uv)
# and Node are installed directly in the devcontainer image for exactly this
# reason -- see .devcontainer/devcontainer.json.
#
#   scripts/run.sh
#
# Backend:  http://localhost:8000  (GET /health, POST /solve)
# Frontend: http://localhost:3000  (proxies /solve and /health to the backend)
#
# Ctrl+C stops both. Assumes deps are already installed -- the devcontainer's
# postCreateCommand runs `uv sync --extra dev` and `npm install` once on
# container creation; re-run those yourself after a dependency change
# (pyproject.toml/uv.lock, frontend/package.json).
set -euo pipefail

basedir=$(cd "$(dirname "$0")/.." && pwd)
cd "$basedir"

trap 'kill 0' EXIT

echo "backend:  http://localhost:8000"
echo "frontend: http://localhost:3000"

uv run uvicorn sudoku_solver.api:app --reload --host 0.0.0.0 --port 8000 &
npm start --prefix frontend &

wait
