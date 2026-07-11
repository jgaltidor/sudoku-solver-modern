#!/usr/bin/env python3
"""Example invocation of scripts/solver.py, showing how to solve a board
from the command line. Run from any directory:

    python scripts/example_solve.py

which is equivalent to, from the repo root:

    python scripts/solver.py example_inputs/solve_input_example.json

See example_inputs/solve_input_example.json for the input format
({"board": [[9x9 ints, 0 for blank cells]]}), and scripts/solver.py's own
docstring for the [output.json] argument and general usage.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    basedir = Path(__file__).resolve().parent.parent
    return subprocess.call(
        [
            sys.executable,
            str(basedir / "scripts" / "solver.py"),
            str(basedir / "example_inputs" / "solve_input_example.json"),
        ]
    )


if __name__ == "__main__":
    raise SystemExit(main())
