#! /usr/bin/env bash
# Thin convenience wrapper for `uv run scripts/solver.py` -- shorter to type,
# not a toolchain necessity. Unlike the old repo's scripts/solve.sh (see
# solver.py's own docstring), nothing here is required to invoke the solver;
# this just forwards every argument straight through.
#
#   scripts/solver.sh <input.json> [output.json]
set -euo pipefail

exec uv run "$(dirname "$0")/solver.py" "$@"
