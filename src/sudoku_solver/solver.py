"""Sudoku solving via Google OR-Tools' CP-SAT solver.

Row/column/box uniqueness are each a single add_all_different call here --
CP-SAT's native AllDifferent constraint replaces the nested pairwise
not-equal loops the old Inez/SMT-based solver needed for the same rules.
"""
from __future__ import annotations

from ortools.sat.python import cp_model

from .board import BLANK, BOARD_SIZE, BOX_SIZE, Board


def solve(input_board: Board) -> dict:
    model = cp_model.CpModel()

    cells = {
        (r, c): model.new_int_var(1, 9, f"cell_{r}_{c}")
        for r in range(BOARD_SIZE)
        for c in range(BOARD_SIZE)
    }

    for r in range(BOARD_SIZE):
        for c in range(BOARD_SIZE):
            value = input_board[r][c]
            if value != BLANK:
                model.add(cells[r, c] == value)

    for r in range(BOARD_SIZE):
        model.add_all_different(cells[r, c] for c in range(BOARD_SIZE))

    for c in range(BOARD_SIZE):
        model.add_all_different(cells[r, c] for r in range(BOARD_SIZE))

    for box_row in range(0, BOARD_SIZE, BOX_SIZE):
        for box_col in range(0, BOARD_SIZE, BOX_SIZE):
            model.add_all_different(
                cells[box_row + dr, box_col + dc]
                for dr in range(BOX_SIZE)
                for dc in range(BOX_SIZE)
            )

    solver = cp_model.CpSolver()
    status = solver.solve(model)
    has_solution = status in (cp_model.OPTIMAL, cp_model.FEASIBLE)

    solved_board = None
    if has_solution:
        solved_board = [
            [solver.value(cells[r, c]) for c in range(BOARD_SIZE)]
            for r in range(BOARD_SIZE)
        ]

    return {
        "input_board": input_board,
        "has_solution": has_solution,
        "solved_board": solved_board,
    }
