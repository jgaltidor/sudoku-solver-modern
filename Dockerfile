# Backend image: FastAPI + OR-Tools. Editable install (-e) so
# docker-compose.yml can bind-mount src/ over this path for a live-reload
# dev loop, the same edit-and-see-it experience the old repo's compose
# setup had -- just without needing a bind-mount-plus-rebuild dance, since
# there's no compiled artifact here the way sudoku_solver_inez/src's
# sudoku.cma was.
FROM python:3.12-slim

# Official distroless uv image as a COPY source -- no curl/pip bootstrap
# needed to get the uv binary itself.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# The cache mount below is a different filesystem than /app, so uv can't
# hardlink into it -- copy instead of falling back with a warning every build.
ENV UV_LINK_MODE=copy

# Dependencies first, before copying src/ -- src/ is bind-mounted over by
# docker-compose.yml anyway for the dev loop, so this keeps edits there from
# invalidating (and re-triggering ortools' slow resolve+install on) this
# layer. --frozen: use uv.lock exactly as committed, no re-resolving.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project

COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["uvicorn", "sudoku_solver.api:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
