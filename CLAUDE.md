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

Backend (from repo root, venv at `.venv`):
```bash
source .venv/bin/activate
pip install -e '.[dev]'                 # install backend + dev deps
uvicorn sudoku_solver.api:app --reload  # run backend on :8000
pytest tests/                           # run all tests
pytest tests/ -v                        # verbose (matches CI)
pytest tests/test_solver.py             # solver-level tests only
pytest tests/test_api.py                # FastAPI TestClient tests only
pytest tests/ -k unique_solution        # run a single fixture case by name
```

CLI (from repo root, same venv as above, without going through the HTTP API):
```bash
python scripts/solver.py <input.json> [output.json]  # solve one board, print or write the result
python scripts/example_solve.py                      # worked example, solves example_inputs/solve_input_example.json
```

Frontend (from `frontend/`):
```bash
npm install
npm start     # vite dev server on :3000
npm run build
```

Both together via Docker:
```bash
docker compose up --build   # backend :8000, frontend :3000, bind-mounted source for live reload
```

CI (`.github/workflows/ci.yml`) only runs the Python test suite (`pip install -e '.[dev]'` then
`pytest tests/ -v`) on push/PR — there is no frontend build/lint/test step in CI.

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
