"""Parity tests against the fixtures from the original OCaml/Inez solver's
tests/solver/ suite (sudoku_solver_service_inez), copied into tests/cases
and tests/expected here. Same cases, same expected results -- proving this
OR-Tools rewrite agrees with the original, including the box_duplicate case
(a regression test for a real bug in the original: it used to only
constrain rows/columns, not 3x3 boxes).
"""
import json
from pathlib import Path

import pytest

from sudoku_solver import solve
from sudoku_solver.board import board_from_dict

CASES_DIR = Path(__file__).parent / "cases"
EXPECTED_DIR = Path(__file__).parent / "expected"

CASE_NAMES = sorted(p.stem for p in CASES_DIR.glob("*.json"))


@pytest.mark.parametrize("name", CASE_NAMES)
def test_case(name):
    input_data = json.loads((CASES_DIR / f"{name}.json").read_text())
    expected = json.loads((EXPECTED_DIR / f"{name}.json").read_text())

    board = board_from_dict(input_data)
    result = solve(board)

    assert result["has_solution"] == expected["has_solution"]
    if "solved_board" in expected:
        assert result["solved_board"] == expected["solved_board"]
