#!/usr/bin/env python3
"""Solve a single Sudoku board from the command line, without going through
the HTTP API.

Unlike sudoku_solver_service_inez's scripts/solve.sh, this doesn't need a
temp working directory or a toolchain on PATH -- solve() is a pure
in-process function (see src/sudoku_solver/solver.py), so this script just
calls it directly.

Usage: python scripts/solver.py <input.json> [output.json]

  input.json   A JSON file with a "board" key: a 9x9 array of arrays of
               ints, 0 for blank cells. Same format the HTTP API's POST
               body and example_inputs/solve_input_example.json use.
  output.json  Where to write the solver's result (input_board/
               has_solution/solved_board). Defaults to printing to stdout
               if omitted.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from sudoku_solver.board import board_from_dict
from sudoku_solver.solver import solve


def _format_board(board: list[list[int]] | None, indent: str) -> str:
    if board is None:
        return "null"
    rows = ",\n".join(f"{indent}  {row}" for row in board)
    return f"[\n{rows}\n{indent}]"


def _format_result(result: dict) -> str:
    # json.dumps(indent=2) puts every int on its own line for nested lists,
    # which makes a 9x9 board unreadable. Format board rows on one line
    # instead, matching this repo's own tests/cases/*.json fixtures.
    return (
        "{\n"
        f'  "input_board": {_format_board(result["input_board"], "  ")},\n'
        f'  "has_solution": {json.dumps(result["has_solution"])},\n'
        f'  "solved_board": {_format_board(result["solved_board"], "  ")}\n'
        "}"
    )


def main(argv: list[str]) -> int:
    if not 1 <= len(argv) <= 2:
        print(__doc__, file=sys.stderr)
        return 1

    input_path = Path(argv[0])
    if not input_path.is_file():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return 1

    data = json.loads(input_path.read_text())
    board = board_from_dict(data)
    result = solve(board)
    output_json = _format_result(result)

    if len(argv) == 2:
        output_path = Path(argv[1])
        output_path.write_text(output_json + "\n")
        print(f"Wrote {output_path}", file=sys.stderr)
    else:
        print(output_json)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
