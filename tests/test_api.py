"""HTTP-level parity tests for the FastAPI layer, using the same
tests/cases + tests/expected fixtures as test_solver.py -- so the API layer
can't silently diverge from the solver-level tests.
"""

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from sudoku_solver.api import app

CASES_DIR = Path(__file__).parent / "cases"
EXPECTED_DIR = Path(__file__).parent / "expected"

CASE_NAMES = sorted(p.stem for p in CASES_DIR.glob("*.json"))

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.parametrize("name", CASE_NAMES)
def test_solve_case(name):
    input_data = json.loads((CASES_DIR / f"{name}.json").read_text())
    expected = json.loads((EXPECTED_DIR / f"{name}.json").read_text())

    response = client.post("/solve", json=input_data)
    assert response.status_code == 200

    body = response.json()
    assert body["has_solution"] == expected["has_solution"]
    if "solved_board" in expected:
        assert body["solved_board"] == expected["solved_board"]


def test_solve_rejects_wrong_shape():
    response = client.post("/solve", json={"board": [[1, 2, 3]]})
    assert response.status_code == 422


def test_solve_rejects_out_of_range_values():
    board = [[0] * 9 for _ in range(9)]
    board[0][0] = 10
    response = client.post("/solve", json={"board": board})
    assert response.status_code == 422
