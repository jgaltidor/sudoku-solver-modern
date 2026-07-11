# Backend image: FastAPI + OR-Tools. Editable install (-e) so
# docker-compose.yml can bind-mount src/ over this path for a live-reload
# dev loop, the same edit-and-see-it experience the old repo's compose
# setup had -- just without needing a bind-mount-plus-rebuild dance, since
# there's no compiled artifact here the way sudoku_solver_inez/src's
# sudoku.cma was.
FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml ./
COPY src ./src

RUN pip install --no-cache-dir -e .

EXPOSE 8000

CMD ["uvicorn", "sudoku_solver.api:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
