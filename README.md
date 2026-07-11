# sudoku-solver-modern

[![CI](https://github.com/jgaltidor/sudoku-solver-modern/actions/workflows/ci.yml/badge.svg)](https://github.com/jgaltidor/sudoku-solver-modern/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Sudoku-solving web service with a Python/FastAPI backend and a React frontend.

## Getting started

There are two ways to get a running app, depending on where you're starting from:

### Docker Desktop, no editing (fastest)

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

Run this from a regular host terminal, not a VS Code devcontainer terminal -- see the note in
[Devcontainer](#devcontainer) below for why that combination doesn't work.

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

See [Devcontainer](#devcontainer) below for the full edit/build/run/test loop from here.

Either path gets you a running app. From here:

- Running the test suite -- see [Testing](#testing) below (needs [uv](https://docs.astral.sh/uv/),
  separately from the Docker path above).
- Every other command in this README -- see [Running it](#running-it) for the full reference.

## CLI

Solve a board from the command line, without the HTTP API:

```bash
scripts/solver.sh example_inputs/solve_input_example.json
```

which prints `{"input_board": [...], "has_solution": true, "solved_board": [...]}` to stdout, or
pass a second argument to write the result to a file instead:

```bash
scripts/solver.sh example_inputs/solve_input_example.json solved.json
```

`example_inputs/solve_input_example.json` is a worked example of the input format (also see
`tests/cases/` -- any of those files work as input too). To run that same example directly:

```bash
uv run scripts/example_solve.py
```

`scripts/solver.sh` is just `uv run scripts/solver.py "$@"` -- a typing-convenience wrapper, not a
toolchain necessity: unlike the old repo's `scripts/solve.sh`, this doesn't need a toolchain on `PATH`
or a temp-dir/config-file trick to invoke the solver, since `solve()` is a pure in-process function
here. Calling `uv run scripts/solver.py` directly instead works identically.

## Layout

```
src/sudoku_solver/
  board.py     # board representation, JSON (de)serialization
  solver.py    # OR-Tools CP-SAT solver
  api.py       # FastAPI app: POST /solve, GET /health
frontend/      # React + Vite UI (copied from the old repo, re-wired to this backend)
  eslint.config.js, .prettierrc.json  # lint/format rules (added on top of the copied code)
  src/index.test.jsx  # drives the mounted app through its own UI, fetch mocked (vitest)
scripts/
  run.sh            # launch backend + frontend as native processes (devcontainer dev loop)
  dev-run.sh        # restart the Docker Compose containers without rebuilding (host terminal only)
  solver.py         # CLI: solve one board from a JSON file, without the HTTP API
  solver.sh         # convenience wrapper: `uv run scripts/solver.py`, args forwarded as-is
  example_solve.py  # worked example invocation of scripts/solver.py
  publish.sh        # push the built backend/frontend images to Docker Hub
example_inputs/
  solve_input_example.json  # sample board used by scripts/example_solve.py
tests/
  cases/       # input boards (also used as POST bodies directly)
  expected/    # expected has_solution / solved_board per case
  test_solver.py  # solver-level tests
  test_api.py      # same cases, through FastAPI's TestClient
uv.lock                # pinned dependency versions (uv)
Dockerfile             # backend image
docker-compose.yml      # backend + frontend together
.devcontainer/          # VS Code Dev Container (Python 3.12 image, no custom build needed)
```

## Running it

This is split by *where you're running the command from* -- devcontainer, host machine, or neither --
since a command from the wrong section can fail in confusing ways (or silently do the wrong thing) in
the other two.

### Devcontainer

Open this repo in VS Code and reopen in the container (`.devcontainer/devcontainer.json`) for a full-stack
dev environment: Python (package + dev deps installed via `uv`), Node (via the `node` feature, so
`frontend/`'s npm deps are installed too), and the Docker CLI (via `docker-outside-of-docker`, wired up
against the host's own Docker daemon). (Unlike the old repo's devcontainer, no manual
static-binary/glibc-shim workarounds were needed for any of this -- this image's Debian 13 base has none
of xenial's compatibility constraints.)

**Run:**

```bash
scripts/run.sh
```

runs the backend (`uv run uvicorn sudoku_solver.api:app --reload`) and frontend (`npm start --prefix
frontend`) as native processes side by side, forwarded the same way as [Getting
started](#vs-code-devcontainer-for-editing): http://localhost:3000 / http://localhost:8000/health.
Ctrl+C stops both.

> [!IMPORTANT]
> `docker compose up`/`scripts/dev-run.sh` do *not* work from inside the devcontainer's own terminal --
> see [Docker Compose (host machine)](#docker-compose-host-machine) below for why, and use `scripts/run.sh`
> above instead. `docker compose build` alone is fine here (see **Build** below); it's specifically `up`
> that fails.

**Edit:** source under `src/` and `frontend/` is the same checkout VS Code has open -- no bind mount or
rebuild step, changes take effect on save (`uvicorn --reload`, Vite HMR).

**Build:** `docker compose build` works fine from the devcontainer -- unlike `up`, `build` never touches
a bind mount, so the host-daemon path mismatch described below doesn't apply to it. `npm run build
--prefix frontend` produces just the frontend's static production bundle without touching Docker at all.

**Test / lint:** see [Testing](#testing) and [Linting and formatting](#linting-and-formatting) below --
both run identically in the devcontainer, no Docker involved.

Its `.venv` lives at `/home/vscode/.venv` (`UV_PROJECT_ENVIRONMENT`), not the default `./.venv` --
that default would land inside this bind-mounted workspace and collide with a host checkout's own
(differently-platformed) `.venv` at the same path. `uv run`/`uv sync` find it automatically either way.

The `claude` CLI is also available in the container (via the `claude-code` feature -- your host's own
`claude` binary won't run here, it's a macOS build). Its config/memory lives in a container-local named
volume, not your host's `~/.claude`, so the first run needs its own login: either sign in interactively,
or set `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY` in your host shell before reopening the container
(run `claude setup-token` on the host to mint one) so it's picked up automatically instead.

### Docker Compose (host machine)

> [!IMPORTANT]
> Run every command in this section from a regular host terminal -- never the devcontainer's own
> terminal. Its `docker-outside-of-docker` feature sends Compose's bind mounts (`./src:/app/src`) to the
> *host's* Docker daemon, which resolves them against the devcontainer's own filesystem path
> (`/workspaces/...`), not a real path on the host, and refuses with a "mounts denied"/file-sharing
> error. (`docker compose build` alone is the one exception -- it never touches a bind mount, so it
> works fine from either place; see [Devcontainer](#devcontainer) above.)

```bash
docker compose up --build
```

- Backend: http://localhost:8000 (`GET /health`, `POST /solve`)
- Frontend: http://localhost:3000

The backend image has a `HEALTHCHECK` (`curl`-ing `/health`) baked in, so `docker ps`/`docker compose ps`
show its actual up/down state, not just "container is running." `frontend` waits on that healthcheck
(`depends_on: backend: condition: service_healthy`), not just on the container having started, since
Vite's dev server proxies `/solve`/`/health` straight to it.

Both services bind-mount their own source (`src/`, `frontend/`) for a live-reload dev loop --
`uvicorn --reload` picks up backend changes immediately; Vite's dev server does the same for the
frontend. No rebuild needed for source edits; rebuild (`docker compose build`) only for dependency
changes (`pyproject.toml`, `frontend/package.json`).

After that first `--build`, `scripts/dev-run.sh` (`docker compose up -d`, no rebuild) is a faster way to
restart both containers -- source edits don't need it either, since they already reload live; use
`docker compose build` (or `docker compose up --build` again) by hand first for a dependency/Dockerfile
change, since this script deliberately doesn't rebuild on its own.

`docker-compose.yml` tags both images (`jgaltidor/sudoku-solver-modern-backend`/`-frontend`) for Docker
Hub. After `docker login` and a `docker compose build`, `scripts/publish.sh` pushes them -- mirrors the
old repo's `docker/publish.sh`, just relocated next to this repo's other CLI scripts.

### Local, no Docker

Works in either the devcontainer or a plain host shell, wherever [uv](https://docs.astral.sh/uv/) is
available (`curl -LsSf https://astral.sh/uv/install.sh | sh` on the host; already installed in the
devcontainer) -- it manages `.venv`/`uv.lock` itself, no separate `python -m venv`/`pip install` step,
and `uv run` finds the venv without needing it activated. This is what `scripts/run.sh` runs under the
hood in the devcontainer, split into its two halves here:

```bash
uv sync --extra dev
uv run uvicorn sudoku_solver.api:app --reload
```

```bash
cd frontend && npm install && npm start
```

## Testing

```bash
uv run pytest tests/
```

`tests/cases/`/`tests/expected/` are the same fixtures the old repo's `tests/solver/` uses (including
`box_duplicate.json`, the regression case for a real bug in the old solver: it used to only constrain
rows/columns, not 3x3 boxes). `test_solver.py` exercises the OR-Tools solver directly; `test_api.py` runs
the same cases through the FastAPI layer, plus a couple of request-validation checks.

```bash
cd frontend
npm run test
```

`src/index.test.jsx` drives the actual mounted app through its own UI (Solve/Clear buttons, cell
inputs) with `fetch` mocked, rather than testing an exported component in isolation -- `index.jsx`
doesn't export one, it just mounts itself into `#root` as an import-time side effect.

## Linting and formatting

```bash
uv run ruff check .           # lint
uv run ruff format --check .  # format check; drop --check to auto-fix
```

```bash
cd frontend
npm run lint           # eslint
npm run format:check   # prettier --check; npm run format to auto-fix
```

`.github/workflows/ci.yml` runs all of these (plus `pytest`, `npm run test`, `npm run build`, and
`docker compose build` to catch a broken `Dockerfile`/`docker-compose.yml`) on every push/PR.

## Example request

```bash
curl -X POST http://localhost:8000/solve \
  -H "Content-Type: application/json" \
  -d @tests/cases/unique_solution.json
```

Returns `{"input_board": [...], "has_solution": true, "solved_board": [...]}`.

## Comparison with the old repo

A modern rewrite of [`sudoku_solver_service_inez`](https://github.com/jgaltidor/sudoku_solver_service_inez): same idea (a
Sudoku-solving web service with a React frontend), rebuilt on a much simpler stack. This repo is
completely independent of the old one -- no shared code, build system, or git history.

| | Old repo | This repo |
|---|---|---|
| Solver | OCaml, hand-written SMT/ILP constraints via [Inez](https://github.com/vasilisp/inez)/SCIP | Python, [OR-Tools](https://developers.google.com/optimization) CP-SAT, one `add_all_different` call per row/column/box |
| Backend | Java, NanoHTTPD, shells out to a solver subprocess per request | Python, [FastAPI](https://fastapi.tiangolo.com/), calls the solver in-process |
| Base image | `ubuntu:16.04` (camlp4-era OCaml/SCIP toolchain) | `python:3.12-slim` / `mcr.microsoft.com/devcontainers/python:3.12` |
| Frontend | React + Vite | Same (copied, not shared) |

## License

[MIT](LICENSE)
