"""FastAPI REST layer, replacing the old NanoHTTPD-based App.java.

Unlike the old server -- which shells out to a separate solver process per
request via ProcessBuilder, writing/reading JSON files on disk -- this calls
the OR-Tools solver in-process directly, since it's a plain Python library
call rather than a dynamically-compiled OCaml toplevel invocation.
"""

from __future__ import annotations

from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, field_validator

from .board import BOARD_SIZE
from .solver import solve as solve_board

# Version from package metadata (pyproject.toml), not a hand-maintained literal
# that silently drifts. Shows up in /openapi.json and /docs. The package is
# always installed here (editable in dev, wheel in Docker); the fallback is just
# belt-and-braces.
try:
    _version = _pkg_version("sudoku-solver")
except PackageNotFoundError:
    _version = "0.0.0"

app = FastAPI(title="Sudoku Solver", version=_version)


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


# Dockerfile.combined's single-image build copies the frontend's production
# build (`vite build`) to this path so the backend can serve it directly,
# instead of a separate frontend process/proxy. The two-image dev setup
# (Dockerfile + docker-compose.yml) and the test suite never populate this
# path, so the mount is skipped there. Registered after the routes above so
# they still take precedence over this catch-all -- Starlette matches routes
# in registration order.
_FRONTEND_DIST = Path(__file__).resolve().parent.parent.parent / "frontend_dist"
if _FRONTEND_DIST.is_dir():
    app.mount("/", StaticFiles(directory=_FRONTEND_DIST, html=True), name="frontend")
