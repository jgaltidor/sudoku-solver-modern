# sudoku-solver-modern

A modern rewrite of [`sudoku_solver_service_inez`](../sudoku_solver_service_inez): same idea (a
Sudoku-solving web service with a React frontend), rebuilt on a much simpler stack. This repo is
completely independent of the old one -- no shared code, build system, or git history.

| | Old repo | This repo |
|---|---|---|
| Solver | OCaml, hand-written SMT/ILP constraints via [Inez](https://github.com/vasilisp/inez)/SCIP | Python, [OR-Tools](https://developers.google.com/optimization) CP-SAT, one `add_all_different` call per row/column/box |
| Backend | Java, NanoHTTPD, shells out to a solver subprocess per request | Python, [FastAPI](https://fastapi.tiangolo.com/), calls the solver in-process |
| Base image | `ubuntu:16.04` (camlp4-era OCaml/SCIP toolchain) | `python:3.12-slim` / `mcr.microsoft.com/devcontainers/python:3.12` |
| Frontend | React + Vite | Same (copied, not shared) |

## Layout

```
src/sudoku_solver/
  board.py     # board representation, JSON (de)serialization
  solver.py    # OR-Tools CP-SAT solver
  api.py       # FastAPI app: POST /solve, GET /health
frontend/      # React + Vite UI (copied from the old repo, re-wired to this backend)
scripts/
  solver.py         # CLI: solve one board from a JSON file, without the HTTP API
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

`docker-compose.yml` tags both images (`jgaltidor/sudoku-solver-modern-backend`/`-frontend`) for Docker
Hub. After `docker login` and a `docker compose build`, `scripts/publish.sh` pushes them -- mirrors the
old repo's `docker/publish.sh`, just relocated next to this repo's other CLI scripts.

### Devcontainer

Open this repo in VS Code and reopen in the container (`.devcontainer/devcontainer.json`) for a full-stack
dev environment: Python (package + dev deps installed via `uv`), Node (via the `node` feature, so
`frontend/`'s npm deps are installed too), and the Docker CLI (via `docker-outside-of-docker`, wired up
against the host's own Docker daemon). From its integrated terminal you can edit, build, and run
everything -- `uv run uvicorn sudoku_solver.api:app --reload`, `npm start --prefix frontend`, and
`docker compose up --build` all work directly, no separate host terminal needed. (Unlike the old repo's
devcontainer, no manual static-binary/glibc-shim workarounds were needed for any of this -- this image's
Debian 13 base has none of xenial's compatibility constraints.)

Its `.venv` lives at `/home/vscode/.venv` (`UV_PROJECT_ENVIRONMENT`), not the default `./.venv` --
that default would land inside this bind-mounted workspace and collide with a host checkout's own
(differently-platformed) `.venv` at the same path. `uv run`/`uv sync` find it automatically either way.

The `claude` CLI is also available in the container (via the `claude-code` feature -- your host's own
`claude` binary won't run here, it's a macOS build). Its config/memory lives in a container-local named
volume, not your host's `~/.claude`, so the first run needs its own login: either sign in interactively,
or set `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY` in your host shell before reopening the container
(run `claude setup-token` on the host to mint one) so it's picked up automatically instead.

### Local, no Docker

Requires [uv](https://docs.astral.sh/uv/) (`curl -LsSf https://astral.sh/uv/install.sh | sh`), which
manages `.venv`/`uv.lock` itself -- no separate `python -m venv`/`pip install` step, and `uv run` finds
the venv without needing it activated.

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

## Linting and formatting

```bash
uv run ruff check .           # lint
uv run ruff format --check .  # format check; drop --check to auto-fix
```

`.github/workflows/ci.yml` runs both on every push/PR, alongside `pytest`.

## CLI

Solve a board from the command line, without the HTTP API:

```bash
uv run scripts/solver.py example_inputs/solve_input_example.json
```

which prints `{"input_board": [...], "has_solution": true, "solved_board": [...]}` to stdout, or
pass a second argument to write the result to a file instead:

```bash
uv run scripts/solver.py example_inputs/solve_input_example.json solved.json
```

`example_inputs/solve_input_example.json` is a worked example of the input format (also see
`tests/cases/` -- any of those files work as input too). To run that same example directly:

```bash
uv run scripts/example_solve.py
```

Unlike the old repo's `scripts/solve.sh`, this doesn't need a toolchain on `PATH` or a
temp-dir/config-file trick to invoke the solver -- `solve()` is a pure in-process function here.

## Example request

```bash
curl -X POST http://localhost:8000/solve \
  -H "Content-Type: application/json" \
  -d @tests/cases/unique_solution.json
```

Returns `{"input_board": [...], "has_solution": true, "solved_board": [...]}`.
