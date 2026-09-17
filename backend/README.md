# Tandem Backend

FastAPI service for Tandem, a predictive Citi Bike navigation application.

## Layout

| Path | Purpose |
| --- | --- |
| `app/api/` | HTTP routes and the aggregate router |
| `app/core/` | Configuration and cross-cutting concerns |
| `app/db/` | SQLAlchemy base, engine, session management |
| `app/models/` | ORM models (`Base.metadata` for Alembic) |
| `app/schemas/` | Pydantic request/response models |
| `app/services/` | Business logic between API and database |
| `app/routing/` | Route planning over the bike network (placeholder) |
| `app/prediction/` | Station availability prediction (placeholder) |
| `alembic/` | Migration environment |
| `tests/` | pytest suite |

## Commands

Run these from `backend/` (the root `Makefile` wraps them):

```bash
uv sync                                    # install dependencies
uv run uvicorn app.main:app --reload       # serve on :8000
uv run pytest                              # run tests
uv run ruff check . && uv run ruff format --check .
uv run alembic upgrade head                # apply migrations
uv run alembic revision --autogenerate -m "message"
```

## Conventions

- **All timestamps are UTC.** Database columns are `TIMESTAMPTZ`, the API emits
  ISO 8601 with an explicit offset, and conversion to America/New_York happens
  only in the frontend.
- Configuration comes from environment variables via `app.core.config`. Nothing
  reads `os.environ` directly.
- The test suite runs without a database. Tests that need Postgres must set it
  up explicitly.
