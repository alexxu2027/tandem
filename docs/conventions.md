# Conventions

## Timestamps: UTC everywhere

**UTC is the internal timestamp standard for Tandem.** This is not a
preference — bike availability prediction depends on joining data across
sources over long time ranges, and New York observes daylight saving time. A
local-time pipeline silently produces one duplicated hour and one missing hour
every year, exactly in the historical data a model trains on.

The rules:

| Layer | Rule |
| --- | --- |
| Database | Columns are `TIMESTAMPTZ`, and the database is pinned to UTC in `scripts/init_postgis.sql`. Never `TIMESTAMP` without a zone. |
| Python | Always timezone-aware: `datetime.now(UTC)`, never `datetime.now()` or the deprecated `utcnow()`. |
| API | ISO 8601 with an explicit offset, e.g. `2026-09-17T14:03:11.482Z`. |
| Ingestion | Sources reporting local time are converted to UTC at the moment of ingestion. The local value is never stored. |
| Containers / CI | `TZ=UTC` is set for every service and every CI job. |
| Frontend | The **only** place that converts to `America/New_York`, and only at render time. |

Partition keys, file paths and batch windows use UTC dates too. A "day" of
Citi Bike data is a UTC day, not a New York day; the offset is consistent and
documented, which is what matters.

## Naming

- Python: `snake_case`; modules and packages lowercase. Enforced by Ruff's `N` rules.
- TypeScript: `camelCase` for values, `PascalCase` for components and types.
- Database: `snake_case`, plural table names (`stations`, `station_status`).
- Constraint and index names come from the naming convention in
  `backend/app/db/base.py`, so Alembic migrations stay stable and reversible.

## Code style

| Language | Tool | Command |
| --- | --- | --- |
| Python | Ruff (lint + format), 100-column lines | `make lint-backend` |
| TypeScript | ESLint (`eslint-config-next`) + `tsc --noEmit` | `make lint-frontend` |

`make format` auto-fixes both. CI runs the check-only variants and fails on a
diff, so run `make format` before pushing.

## Configuration

- All configuration comes from environment variables, read through
  `app.core.config`. Nothing else touches `os.environ`.
- Every variable is documented in `.env.example`.
- Secrets never enter the repository. `.env` is gitignored; `.env.example`
  carries only placeholder values.
- In the frontend, only `NEXT_PUBLIC_*` variables reach the browser. Never put
  a secret behind that prefix.

## Layering

```
API routes  ->  services  ->  models / database
```

Routes parse and validate, services hold the logic, models own persistence.
Routes should not build queries directly, and services should not know about
HTTP. `schemas/` (wire format) stays separate from `models/` (storage format)
so the two can evolve independently.

## Commits

Conventional-commit prefixes, scoped to the affected area:

```
feat(backend): add station availability endpoint
fix(pipelines): handle missing GBFS ttl field
chore(ci): cache pnpm store
```
