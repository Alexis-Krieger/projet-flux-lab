FROM python:3.12-slim AS build
COPY --from=ghcr.io/astral-sh/uv:0.12.23 /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock README.md ./
COPY src ./src
RUN uv sync --locked --no-dev --no-editable

FROM python:3.12-slim
RUN useradd --system --uid 10001 --no-create-home appuser \
    && mkdir /data && chown appuser /data
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH" \
    FLUX_LAB_DB=/data/flux_lab.db
USER appuser
EXPOSE 8000
CMD ["uvicorn", "flux_lab.api:app", "--host", "0.0.0.0", "--port", "8000"]

