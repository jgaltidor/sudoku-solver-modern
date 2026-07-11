# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Sudoku-solving web service: Python/FastAPI backend using OR-Tools CP-SAT, React+Vite frontend. It is a
modern rewrite of a sibling repo (`sudoku_solver_service_inez`, OCaml/Inez/SCIP solver + Java/NanoHTTPD
backend) — completely independent, no shared code or git history. Comments in the source
(`api.py`, `solver.py`, `board.py`) explicitly call out what changed vs. that old implementation; read
them when touching solver or API logic, they carry real design rationale (e.g. why CP-SAT's
`add_all_different` replaced pairwise not-equal constraints, why the solver now runs in-process instead
of shelling out per request).

## Commands

Backend (from repo root; [uv](https://docs.astral.sh/uv/) manages `.venv` and `uv.lock` — no manual
`pip`/`venv` steps, and `uv run` finds the venv itself without activating it):
```bash
uv sync --extra dev                        # install backend + dev deps from uv.lock into .venv
uv run uvicorn sudoku_solver.api:app --reload  # run backend on :8000
uv run pytest tests/                       # run all tests
uv run pytest tests/ -v                    # verbose (matches CI)
uv run pytest tests/test_solver.py         # solver-level tests only
uv run pytest tests/test_api.py            # FastAPI TestClient tests only
uv run pytest tests/ -k unique_solution    # run a single fixture case by name
uv run ruff check .                        # lint (matches CI)
uv run ruff format --check .               # format check (matches CI); drop --check to auto-fix
```

CLI (from repo root, without going through the HTTP API):
```bash
uv run scripts/solver.py <input.json> [output.json]  # solve one board, print or write the result
uv run scripts/example_solve.py                      # worked example, solves example_inputs/solve_input_example.json
```

Frontend (from `frontend/`):
```bash
npm install
npm start            # vite dev server on :3000
npm run build
npm run test          # vitest (matches CI)
npm run lint          # eslint (matches CI)
npm run format:check  # prettier --check (matches CI); npm run format to auto-fix
```

Both together via Docker:
```bash
docker compose up --build   # backend :8000, frontend :3000, bind-mounted source for live reload
scripts/publish.sh          # push the built images to Docker Hub (docker login + docker compose build first)
```

CI (`.github/workflows/ci.yml`) runs three jobs on push/PR: `test` (`uv sync --extra dev`, `pytest`,
`ruff check`, `ruff format --check`), `frontend` (`npm ci`, `vitest`, `eslint`, `prettier --check`, `vite
build`), and `docker-build` (`docker compose build`, to catch a broken `Dockerfile`/`docker-compose.yml`
before it reaches a real build).

## Architecture

```
src/sudoku_solver/
  board.py     # Board = list[list[int]], 9x9, 0 = blank. JSON (de)serialization.
  solver.py    # OR-Tools CP-SAT model: one add_all_different per row/column/3x3 box
  api.py       # FastAPI app: POST /solve, GET /health
frontend/      # React + Vite UI, copied from the old repo and re-wired to this backend's API shape
scripts/
  solver.py         # CLI: solve one board from a JSON file, without the HTTP API
  example_solve.py  # worked example invocation of scripts/solver.py
  publish.sh        # push the built backend/frontend images to Docker Hub
example_inputs/
  solve_input_example.json  # sample board used by scripts/example_solve.py
tests/
  cases/       # input boards (also valid POST /solve request bodies as-is)
  expected/    # expected has_solution / solved_board per case, keyed by matching filename
  test_solver.py  # calls sudoku_solver.solve() directly
  test_api.py      # same cases through FastAPI's TestClient, plus request-validation checks
```

Key points:

- **Test fixtures are the parity contract.** `tests/cases/*.json` and `tests/expected/*.json` are paired
  by filename and shared verbatim between `test_solver.py` and `test_api.py`, and were copied from the
  old OCaml repo's fixture suite to prove behavioral parity. `box_duplicate.json` is a regression test
  for a real bug in the old solver (it only constrained rows/columns, not 3x3 boxes) — do not
  "fix"/simplify it away. When adding a new board case, add both a `cases/<name>.json` input and a
  matching `expected/<name>.json`; both test files auto-discover cases by scanning `cases/*.json`, so no
  test code changes are needed to add a case.
- **Solver is a pure function.** `solve(board) -> dict` in `solver.py` takes a `Board` and returns
  `{input_board, has_solution, solved_board}`. It has no FastAPI/HTTP dependency — `api.py` is a thin
  Pydantic-validation wrapper around it.
- **Validation lives in two places on purpose.** `board.py`'s `board_from_dict` and `api.py`'s
  `SolveRequest.field_validator` both check the 9x9 shape (plus 0-9 range in the API layer) — the former
  for direct/test use, the latter for HTTP request validation with proper 422 responses.
- **`uv`/`uv.lock` replaced `pip`/`venv` everywhere** (local dev, `Dockerfile`, CI, devcontainer) for
  faster installs and real dependency pinning — `ortools` alone pulls in ~30 transitive packages
  (numpy, pandas, protobuf, ...) that `pip` was re-resolving from scratch on every fresh install. Commit
  `uv.lock` alongside any `pyproject.toml` dependency change (`uv lock` regenerates it). The devcontainer
  relocates the venv to `/home/vscode/.venv` via `UV_PROJECT_ENVIRONMENT` rather than the default
  `./.venv`, since that default would otherwise land inside this bind-mounted workspace and collide with
  a host checkout's own (differently-platformed) `.venv` at the same path.
- **`docker-compose.yml`'s `frontend` waits on `backend`'s `HEALTHCHECK`** (`condition:
  service_healthy`, not just container-started) before starting, since Vite's dev server proxies
  `/solve`/`/health` straight to it.
- **`frontend/`'s ESLint/Prettier config was added, and the existing (copied-from-the-old-repo) code
  reformatted to match**, in the same commit that wired both into CI — see `frontend/eslint.config.js`'s
  own comments for the deliberate rule overrides (old-style class components, no PropTypes). `vite.config.js`
  needs `globals.node` specifically, not `globals.browser`, since it runs at dev-server startup under
  Node, not in the bundled browser code.
- **`src/index.jsx` has no exported component** — it mounts itself into `#root` as an import-time
  side effect (`createRoot(...).render(<Game />)` at module scope), so `index.test.jsx` imports it once
  in `beforeAll` (wrapped in `act()`, since React 18's `createRoot().render()` schedules rather than
  flushes synchronously — omitting that left `#root` empty when the first test's assertions ran) and
  drives the single mounted instance through its own UI for every test after that, rather than
  rendering a fresh tree per test. `setupTests.js` also sets `IS_REACT_ACT_ENVIRONMENT = true`, since
  React logs "not wrapped in act" warnings without it even when it is.
- **The devcontainer's Node version is pinned to `20`**, matching `frontend/Dockerfile` and CI's
  `node-version` — it was previously `"lts"`, which floats (resolved to Node 24 when last checked) and
  had silently diverged from what Docker/CI actually run the app on.
