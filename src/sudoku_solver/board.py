"""Board representation and JSON (de)serialization.

A Board is a 9x9 list of lists of ints, 0 for blank cells -- the same shape
used by the JSON payloads in this project's own tests/ fixtures.
"""
from __future__ import annotations

Board = list[list[int]]

BOARD_SIZE = 9
BOX_SIZE = 3
BLANK = 0


def board_from_dict(data: dict) -> Board:
    board = data["board"]
    if len(board) != BOARD_SIZE or any(len(row) != BOARD_SIZE for row in board):
        raise ValueError(f"board must be {BOARD_SIZE}x{BOARD_SIZE}")
    return board


def board_to_dict(board: Board) -> dict:
    return {"board": board}
