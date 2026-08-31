# Modern Sudoku Solver Web Service

[![CI](https://github.com/jgaltidor/sudoku-solver-modern/actions/workflows/ci.yml/badge.svg)](https://github.com/jgaltidor/sudoku-solver-modern/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Sudoku-solving web service with a Python/FastAPI backend (using Google OR-Tools' CP-SAT solver) and a
React frontend.

## Getting started

There are three ways to get a running app, depending on where you're starting from:

### Docker Hub, no clone (fastest)

Prerequisites: [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine).

```bash
docker run -p 8000:8000 jgaltidor/sudoku-solver-modern:latest
```

Open http://localhost:8000. This is a single combined image (frontend's production build served
directly by the backend, one process/port) -- no repo clone, no `docker-compose.yml`. See
`Dockerfile.combined` in [DEVELOPMENT.md](DEVELOPMENT.md#docker-compose-host-machine) for how it differs
from the two-image dev setup below.

### Docker Desktop, no editing

Prerequisites: git, and [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker
Engine + the Compose plugin).

1. Clone the repo:

   ```bash
   git clone https://github.com/jgaltidor/sudoku-solver-modern.git
   cd sudoku-solver-modern
   ```

2. Build and start both services:

   ```bash
   docker compose up --build
   ```

3. Open the app:

   - Frontend: http://localhost:3000
   - Backend health check: http://localhost:8000/health

Run this from a regular host terminal, not a VS Code devcontainer terminal -- see
[Devcontainer](DEVELOPMENT.md#devcontainer) in DEVELOPMENT.md for why that combination doesn't work.

### VS Code devcontainer (for editing)

Prerequisites: git, VS Code with the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers),
and Docker Desktop/Engine (only to build the devcontainer itself).

1. Clone the repo and open it in VS Code, then "Reopen in Container" when prompted (or run the
   "Dev Containers: Reopen in Container" command). This installs Python + Node deps automatically.
2. Launch both services:

   ```bash
   scripts/run.sh
   ```

3. Open the app the same way: http://localhost:3000 / http://localhost:8000/health. Ctrl+C stops both.

See [Devcontainer](DEVELOPMENT.md#devcontainer) in DEVELOPMENT.md for the full edit/build/run/test loop
from here.

Any of these paths gets you a running app. From here, see **[DEVELOPMENT.md](DEVELOPMENT.md)** for everything
else: directory layout, the full day-to-day dev loop (devcontainer, Docker Compose, or plain local),
testing, linting/formatting, the CLI, and how this repo compares to the old one.

## Deploying to AWS

To run the combined production image on an EC2 instance (Terraform-provisioned, Docker installed at
boot), see **[deploy/README.md](deploy/README.md)**. It's built for a low-cost, mostly-stopped
learning setup (free-tier `t3.micro`, no Elastic IP, `terraform destroy` back to ~$0).

## Example request

```bash
curl -X POST http://localhost:8000/solve \
  -H "Content-Type: application/json" \
  -d @tests/cases/unique_solution.json
```

Returns `{"input_board": [...], "has_solution": true, "solved_board": [...]}`.

## License

[MIT](LICENSE)
