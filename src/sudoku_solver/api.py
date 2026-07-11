"""FastAPI REST layer, replacing the old NanoHTTPD-based App.java.

Unlike the old server -- which shells out to a separate solver process per
request via ProcessBuilder, writing/reading JSON files on disk -- this calls
the OR-Tools solver in-process directly, since it's a plain Python library
call rather than a dynamically-compiled OCaml toplevel invocation.
"""

from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel, field_validator

from .board import BOARD_SIZE
from .solver import solve as solve_board

app = FastAPI(title="Sudoku Solver", version="0.1.0")


class SolveRequest(BaseModel):
    board: list[list[int]]

    @field_validator("board")
    @classmethod
    def validate_board(cls, board: list[list[int]]) -> list[list[int]]:
        if len(board) != BOARD_SIZE or any(len(row) != BOARD_SIZE for row in board):
            raise ValueError(f"board must be {BOARD_SIZE}x{BOARD_SIZE}")
        for row in board:
            for value in row:
                if not (0 <= value <= 9):
                    raise ValueError("cell values must be between 0 and 9 (0 = blank)")
        return board


class SolveResponse(BaseModel):
    input_board: list[list[int]]
    has_solution: bool
    solved_board: list[list[int]] | None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/solve", response_model=SolveResponse)
def solve_endpoint(request: SolveRequest) -> SolveResponse:
    return SolveResponse(**solve_board(request.board))
