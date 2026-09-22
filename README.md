# Tandem

[![CI](https://github.com/alexxu2027/tandem/actions/workflows/ci.yml/badge.svg)](https://github.com/alexxu2027/tandem/actions/workflows/ci.yml)

Predictive Citi Bike navigation for New York City.

A rider needs to know whether a bike will be there when they **arrive**, not
whether one is there right now. On a fifteen-minute walk to a station during
rush hour, current availability is a poor predictor of availability on arrival.
Tandem closes that gap: it forecasts bike and dock availability at the time you
would actually get to a station, and plans routes that are likely to work end to
end rather than routes that merely look good at the moment you ask.

> **Status: scaffold.** This repository currently contains project structure,
> local development setup, database scaffolding, configuration, CI and
> documentation. A working `GET /health` endpoint and a frontend shell exist.
> Ingestion, prediction, routing and maps are empty placeholders — they get
> built next.

## Stack

| Layer | Technology |
| --- | --- |
| Frontend | Next.js (App Router), TypeScript, Tailwind CSS |
| Backend | Python, FastAPI, Pydantic, SQLAlchemy, Alembic |
| Database | PostgreSQL 16 + PostGIS 3.6 |
| Python packaging | uv + `pyproject.toml` |
| Frontend packaging | pnpm |
| Local infrastructure | Docker + Docker Compose |
| Testing | pytest |
| Linting / formatting | Ruff (Python), ESLint + `tsc` (TypeScript) |
| CI | GitHub Actions |

## Repository structure

```
tandem/
├── frontend/                 Next.js app (TypeScript, Tailwind)
│   └── src/
│       ├── app/              App Router routes, layouts, global styles
│       └── lib/              Typed backend client and env config
├── backend/                  FastAPI service
│   ├── app/
│   │   ├── api/              Routes and the aggregate router
│   │   ├── core/             Settings and cross-cutting concerns
│   │   ├── db/               SQLAlchemy base, engine, sessions
│   │   ├── models/           ORM models (Base.metadata for Alembic)
│   │   ├── schemas/          Pydantic request/response models
│   │   ├── services/         Business logic
│   │   ├── routing/          Route planning            (placeholder)
│   │   └── prediction/       Availability prediction   (placeholder)
│   ├── tests/                pytest suite
│   └── alembic/              Migration environment
├── pipelines/                Ingestion, one package per source (placeholders)
│   ├── citibike/             GBFS feeds + historical trips
│   ├── weather/              Observations and forecasts
│   ├── nyc_open_data/        Bike lanes, street centrelines
│   └── incidents/            Alerts, closures, collisions
├── ml/                       Model development (placeholders)
│   ├── features/             Feature engineering
│   ├── training/             Training pipelines
│   ├── evaluation/           Backtesting and metrics
│   └── notebooks/            Exploratory analysis only
├── data/                     Gitignored working data
│   ├── raw/                  Untouched source payloads
│   └── processed/            Normalised, analysis-ready outputs
├── docs/                     Architecture, conventions, setup, database
├── scripts/                  Operational helpers (PostGIS init)
├── .github/workflows/        CI
├── .env.example              Documented environment variables
├── docker-compose.yml        Postgres/PostGIS (+ optional app profile)
├── Makefile                  Developer task runner
└── README.md
```

## Prerequisites

[uv](https://docs.astral.sh/uv/), [pnpm](https://pnpm.io/), Node.js >= 20, and
Docker with Compose v2. GNU Make is recommended but optional — every target is a
one-liner shown below. Python itself is not required; uv downloads and pins the
interpreter.

Windows users: the Makefile needs a POSIX shell, so use WSL2 or Git Bash with
GNU Make, or run the underlying commands directly. See
[docs/local-development.md](docs/local-development.md).

### Verification status of this scaffold

This scaffold was built and checked on Windows 11 (arm64) with Git Bash, and
the Docker paths were executed with Docker Desktop 29.8.0. Be explicit about
what is proven:

| Area | Status |
| --- | --- |
| `uv sync`, `pytest` (8 tests), Ruff lint + format | **Verified** — passing |
| `pnpm install`, ESLint, `tsc --noEmit`, `next build` | **Verified** — passing |
| Backend served, `GET /health` and `GET /health/db` | **Verified** — correct responses |
| Frontend server-rendering live backend health | **Verified** — bare metal and in Compose |
| `cp .env.example .env` then loading settings | **Verified** |
| Alembic environment | **Verified** — `upgrade head` offline and online, `alembic check` clean |
| `docker compose up -d db`, PostGIS extensions, UTC | **Verified** — healthy, PostGIS 3.6.1 on PostgreSQL 16 |
| `docker compose --profile app up --build` | **Verified** — both images build and serve on arm64 |
| **`make` targets** | **Unverified locally** — GNU Make is not installed on this machine |

The database, the backend image and the frontend image have now all been run.
The compose `app` profile surfaced one real defect, since fixed: the frontend
container server-rendered `Backend unreachable`, because `NEXT_PUBLIC_API_BASE_URL`
is `localhost:8000` and inside that container `localhost` is the frontend
itself. Server-side fetches now use `API_BASE_URL_INTERNAL`
(`http://backend:8000` in Compose, unset elsewhere).

The Makefile's recipe lines were checked for real tab indentation, but no
target has been *run*; every `make` target has a plain-command equivalent below
that **has** been.

CI passes on GitHub Actions — all three jobs green on `main`.

## Local setup

```bash
git clone <repo-url> tandem
cd tandem

cp .env.example .env     # never commit .env
make setup               # installs backend and frontend dependencies
```

`make setup` creates `.env` if it is missing, runs `uv sync` in `backend/` and
`pnpm install` in `frontend/`.

Without make (this is the path verified on Windows):

```bash
cp .env.example .env              # PowerShell: Copy-Item .env.example .env
cd backend && uv sync && cd ..
cd frontend && pnpm install && cd ..
```

If `pnpm` is missing, `corepack enable pnpm` is the documented install but it
fails with `EPERM` when Node lives in `C:\Program Files\nodejs` without an
elevated shell. `npm install -g pnpm` works from a normal terminal.

## Start PostgreSQL + PostGIS

```bash
make up      # docker compose up -d db, then waits until healthy
```

This starts `imresamu/postgis:16-3.6-bookworm` on `localhost:5432` with a named
volume (`tandem_postgres_data`), so data survives restarts. That image is a
multi-architecture build (amd64 + arm64), so the same compose file works on
Intel and Apple/Snapdragon ARM hosts without a `platform:` override.
`scripts/init_postgis.sql` runs on first creation: it enables `postgis`,
`postgis_topology` and `pg_trgm`, and pins the database to UTC.

```bash
make down    # stop, keeping data
make psql    # open a psql shell
make reset   # DESTRUCTIVE: drop the volume and all data
```

Without make:

```bash
docker compose up -d db
docker compose down
docker compose exec db psql -U tandem -d tandem
```

## Run migrations

```bash
make migrate                            # alembic upgrade head
make migration m="add stations table"   # autogenerate a revision
make downgrade                          # roll back one revision
```

Alembic reads its connection URL from the environment through
`app.core.config`, so no credentials live in `alembic.ini`.
`alembic/versions/` is empty until the first model lands, which means
`make migrate` is a successful no-op today. See
[docs/database.md](docs/database.md).

Without make:

```bash
cd backend && uv run alembic upgrade head
```

## Run the backend

```bash
make backend    # http://localhost:8000
```

| URL | What |
| --- | --- |
| `http://localhost:8000/health` | Liveness — does not touch the database |
| `http://localhost:8000/health/db` | Readiness — database + PostGIS version |
| `http://localhost:8000/docs` | Interactive OpenAPI docs |

```bash
curl localhost:8000/health
# {"status":"ok","service":"Tandem API","version":"0.1.0",
#  "environment":"local","timestamp":"2026-09-17T14:03:11.482291Z"}
```

Without make:

```bash
cd backend && uv run uvicorn app.main:app --reload --port 8000
```

## Run the frontend

```bash
make frontend   # http://localhost:3000
```

The landing page calls `GET /health` and shows the backend status, so it
doubles as a check that the two halves are wired together.

Without make:

```bash
cd frontend && pnpm dev
```

## Run tests

```bash
make test       # backend pytest suite
make lint       # Ruff + ESLint + TypeScript
make format     # auto-fix both sides
```

The backend suite runs **without a database**, so it passes on a fresh clone
before Postgres is started. Tests that need Postgres must set it up explicitly.

Without make:

```bash
cd backend && uv run pytest
cd backend && uv run ruff check . && uv run ruff format --check .
cd frontend && pnpm lint && pnpm typecheck
```

## Everything in Docker

```bash
docker compose --profile app up --build
```

Builds and runs the backend and frontend as containers alongside the database.
The bare-metal workflow above reloads faster for day-to-day work.

## Timestamps are UTC

**UTC is the internal timestamp standard.** Database columns are `TIMESTAMPTZ`,
Python uses timezone-aware `datetime.now(UTC)`, the API emits ISO 8601 with an
explicit offset, containers and CI run with `TZ=UTC`, and ingestion converts
local times at the source.

The frontend is the only place that converts to `America/New_York`, and only at
render time. This is not a style preference: New York observes daylight saving,
so a local-time pipeline produces one duplicated hour and one missing hour every
year — precisely in the historical data the prediction models train on. See
[docs/conventions.md](docs/conventions.md).

## Configuration

All configuration comes from environment variables, documented in
[`.env.example`](.env.example) and read through `app.core.config`.

- `.env` is gitignored and must never be committed.
- `data/raw/` and `data/processed/` are gitignored; datasets and model
  artifacts do not belong in git.
- In the frontend, only `NEXT_PUBLIC_*` variables reach the browser — never put
  a secret behind that prefix.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push to
`main` and every pull request:

| Job | Steps |
| --- | --- |
| **Backend** | Install deps with uv, Ruff lint, Ruff format check, pytest |
| **Migrations** | Start PostGIS, enable extensions, `alembic upgrade head`, `alembic check` |
| **Frontend** | Install deps with pnpm, ESLint, `tsc --noEmit`, production build |

## Documentation

| Document | Contents |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | How the pieces fit together and why |
| [docs/conventions.md](docs/conventions.md) | Timestamps, naming, style, commits |
| [docs/local-development.md](docs/local-development.md) | Detailed setup and troubleshooting |
| [docs/database.md](docs/database.md) | Postgres/PostGIS and migration workflow |

## Not implemented yet

Deliberately out of scope for this scaffold: Citi Bike API ingestion, weather
ingestion, NYC Open Data ingestion, historical data processing, machine
learning, routing, and maps. The directories exist with placeholders so the
module boundaries are settled before the code arrives.
