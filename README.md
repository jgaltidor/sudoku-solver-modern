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
tests/
  cases/       # input boards (also used as POST bodies directly)
  expected/    # expected has_solution / solved_board per case
  test_solver.py  # solver-level tests
  test_api.py      # same cases, through FastAPI's TestClient
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

Both services bind-mount their own source (`src/`, `frontend/`) for a live-reload dev loop --
`uvicorn --reload` picks up backend changes immediately; Vite's dev server does the same for the
frontend. No rebuild needed for source edits; rebuild (`docker compose build`) only for dependency
changes (`pyproject.toml`, `frontend/package.json`).

### Devcontainer

Open this repo in VS Code and reopen in the container (`.devcontainer/devcontainer.json`) for a full-stack
dev environment: Python (package + dev deps installed), Node (via the `node` feature, so `frontend/`'s npm
deps are installed too), and the Docker CLI (via `docker-outside-of-docker`, wired up against the host's
own Docker daemon). From its integrated terminal you can edit, build, and run everything --
`uvicorn sudoku_solver.api:app --reload`, `npm start --prefix frontend`, and `docker compose up --build`
all work directly, no separate host terminal needed. (Unlike the old repo's devcontainer, no manual
static-binary/glibc-shim workarounds were needed for any of this -- this image's Debian 13 base has none
of xenial's compatibility constraints.)

### Local, no Docker

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'
uvicorn sudoku_solver.api:app --reload
```

```bash
cd frontend && npm install && npm start
```

## Testing

```bash
pytest tests/
```

`tests/cases/`/`tests/expected/` are the same fixtures the old repo's `tests/solver/` uses (including
`box_duplicate.json`, the regression case for a real bug in the old solver: it used to only constrain
rows/columns, not 3x3 boxes). `test_solver.py` exercises the OR-Tools solver directly; `test_api.py` runs
the same cases through the FastAPI layer, plus a couple of request-validation checks.

## Example request

```bash
curl -X POST http://localhost:8000/solve \
  -H "Content-Type: application/json" \
  -d @tests/cases/unique_solution.json
```

Returns `{"input_board": [...], "has_solution": true, "solved_board": [...]}`.
