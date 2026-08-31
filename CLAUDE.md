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

## Git workflow

Do not commit directly to `master`. Create a feature branch, commit your changes there, and open a
GitHub pull request via `gh`.

Add an entry under `## [Unreleased]` in `CHANGELOG.md` for user-visible changes (features, fixes,
behavior/config changes) — not for pure refactors, test-only, or CI-only churn.

## Commands

Devcontainer, both services at once (from repo root):
```bash
scripts/run.sh   # backend :8000 + frontend :3000 as native processes, Ctrl+C stops both
```
This is the devcontainer's equivalent of `docker compose up --build` — that command does *not* work
from inside the devcontainer's own terminal (see `scripts/run.sh`'s header comment and CLAUDE.md's Key
points below for why); `scripts/run.sh` is what to reach for there instead.

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
scripts/solver.sh <input.json> [output.json]  # solve one board, print or write the result
uv run scripts/example_solve.py               # worked example, solves example_inputs/solve_input_example.json
```
`scripts/solver.sh` is just `uv run scripts/solver.py "$@"`, a typing-convenience wrapper -- `uv run
scripts/solver.py <input.json> [output.json]` works identically if you'd rather call it directly.

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
scripts/dev-run.sh          # restart both containers after that, without rebuilding
docker build -f Dockerfile.combined -t jgaltidor/sudoku-solver-modern:latest .  # single-image prod build
scripts/publish.sh          # push the dev-loop images plus the combined one to Docker Hub (docker login + the build commands above first)
```

Deploy to AWS EC2 (from repo root, full walkthrough in `deploy/README.md`):
```bash
scripts/deploy.sh                  # build+push linux/amd64 image, then `terraform apply`
scripts/deploy.sh --skip-image     # just `terraform apply` (image already current)
cd deploy/terraform && terraform output app_url   # http://<public-ip> (also: instance_id)
cd deploy/terraform && terraform destroy          # tear it all down (~$0)
```
Needs `aws configure` + `docker login` + `deploy/terraform/terraform.tfvars` first (see
`deploy/README.md`; `deploy/iam-policy.json` is the least-privilege deploy-user policy). The
devcontainer carries `terraform`, `packer`, `aws`, and `tflint`. Terraform state is local
(`deploy/terraform/terraform.tfstate`, gitignored) — `terraform output` is the only record of the
live instance's IP/ID, and both change (IP on stop/start, ID on replacement).

CI (`.github/workflows/ci.yml`) runs four jobs on push/PR: `test` (`uv sync --extra dev`, `pytest`,
`ruff check`, `ruff format --check`), `frontend` (`npm ci`, `vitest`, `eslint`, `prettier --check`, `vite
build`), `docker-build` (`docker compose build`, to catch a broken `Dockerfile`/`docker-compose.yml`
before it reaches a real build), and `deploy-lint` (`terraform fmt`/`validate` + `packer
fmt`/`validate` on `deploy/`, no AWS credentials needed).

## Architecture

```
src/sudoku_solver/
  board.py     # Board = list[list[int]], 9x9, 0 = blank. JSON (de)serialization.
  solver.py    # OR-Tools CP-SAT model: one add_all_different per row/column/3x3 box
  api.py       # FastAPI app: POST /solve, GET /health, plus a conditional static-file
               # mount for Dockerfile.combined's bundled frontend (see Key points)
frontend/      # React + Vite UI, copied from the old repo and re-wired to this backend's API shape
Dockerfile.combined              # single-image build: bundled frontend + backend, one port (see Key points)
Dockerfile.combined.dockerignore # per-Dockerfile ignore override -- see Key points
scripts/
  run.sh            # launch backend + frontend as native processes (devcontainer dev loop)
  dev-run.sh        # restart the Docker Compose containers without rebuilding (host terminal only)
  solver.py         # CLI: solve one board from a JSON file, without the HTTP API
  solver.sh         # convenience wrapper: `uv run scripts/solver.py`, args forwarded as-is
  example_solve.py  # worked example invocation of scripts/solver.py
  publish.sh        # push the backend/frontend images and the combined image to Docker Hub
  deploy.sh         # build+push the combined image, then `terraform apply` (see deploy/)
example_inputs/
  solve_input_example.json  # sample board used by scripts/example_solve.py
CHANGELOG.md       # notable changes per release (Keep a Changelog format)
deploy/            # AWS EC2 deployment -- not needed for local dev (see deploy/README.md)
  terraform/       # provisions one EC2 instance in the default VPC; user_data installs Docker + runs the image on :80
  packer/          # OPTIONAL: bakes an AMI with Docker pre-installed (docker-ami.pkr.hcl) -- deployment works without it
  iam-policy.json  # least-privilege policy for the deploy IAM user
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
- **`Dockerfile.combined` is a third image variant, alongside the two dev-loop images** (`Dockerfile`,
  `frontend/Dockerfile`) that `docker-compose.yml` wires together with bind-mounted live reload. It's a
  multi-stage build: compile the frontend (`vite build`) in one stage, then copy the result into the
  backend image, which serves it as static files -- see `api.py`'s `StaticFiles` mount, gated on a
  `frontend_dist/` directory existing so it's a no-op for the dev-loop backend image, the test suite, and
  local `uv run`/`pytest` (none of which ever populate that path). One process, one port, no
  `--reload`/Vite dev server -- meant to be run standalone (`docker run -p 8000:8000
  jgaltidor/sudoku-solver-modern:latest`), no `docker-compose.yml` involved. It needs its own
  `Dockerfile.combined.dockerignore`: the root `.dockerignore` excludes `frontend/` wholesale (fine for
  the backend-only `Dockerfile`, wrong here since this build needs frontend source) -- BuildKit prefers a
  `<dockerfile-name>.dockerignore` over the plain `.dockerignore` when building with `-f
  Dockerfile.combined`. `scripts/publish.sh` pushes this image too, alongside the two
  `docker-compose.yml` ones.
- **`docker compose up --build` doesn't work from inside the devcontainer's own terminal** — its
  `docker-outside-of-docker` feature bind-mounts `docker.sock` so the CLI works, but the daemon on the
  other end of that socket is the *host's*, not the devcontainer's. Compose's `./src:/app/src`-style
  bind mounts get resolved against the devcontainer's own filesystem path (`/workspaces/...`) before
  being sent over that socket, and the host daemon has no such path — surfacing as a "mounts denied"
  file-sharing error (Docker Desktop) or an outright missing-path error (Docker Engine). `scripts/run.sh`
  exists specifically as the devcontainer-native equivalent (`uv run uvicorn --reload` + `npm start` as
  plain processes, no bind mount involved); reach for plain `docker compose up --build` from a host
  terminal instead if the Docker path specifically is what's needed (e.g. testing the `Dockerfile`s
  themselves). Same restriction applies to `scripts/dev-run.sh` (it's just `docker compose up -d`) —
  it's a host-terminal tool too, for the same reason.
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
- **The devcontainer's Node version tracks `frontend/Dockerfile` and CI's `node-version` in lockstep**
  (currently `26`) — it was originally `"lts"`, which floats and had silently diverged from Docker/CI's
  pinned version; keep these three in sync by hand whenever one changes, since Dependabot's `docker`
  ecosystem PR for `frontend/Dockerfile` only ever touches that one file, not the other two.
- **`deploy/` is self-contained and never touched by local dev or the app image.** Terraform state is
  local + gitignored; `deploy/terraform/.terraform.lock.hcl` *is* committed (locked for linux and
  macOS, amd64 + arm64). The deployed artifact is `Dockerfile.combined`'s image pulled from Docker Hub
  — nothing in `deploy/` rebuilds it. `deploy/packer/` is an optional AMI-baking template kept for
  learning; `user_data.sh` installs Docker at boot regardless, so a Packer AMI only makes first boot
  faster (set `ami_id` in `terraform.tfvars` to use one). No Elastic IP is created on purpose (AWS
  bills EIPs on stopped instances), so the instance's public IP changes across stop/start.
- **The devcontainer gained a `.devcontainer/Dockerfile`** (was a bare `"image":`) solely so Packer
  could be installed at build time — there is no maintained devcontainer feature for Packer and
  HashiCorp's apt repo has no Debian-trixie suite. Terraform + AWS CLI *are* official features
  (`devcontainer-lock.json` pins them). Bump `PACKER_VERSION` in the Dockerfile by hand. `~/.aws` is a
  named volume (like `~/.claude` / `~/.config/gh`) so `aws configure` survives rebuilds; it's in the
  `postCreateCommand` chown for the same root-owned-mountpoint reason as the others.
