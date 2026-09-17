# Database

PostgreSQL 16 with PostGIS 3.6, run locally through Docker Compose using the
multi-architecture `imresamu/postgis:16-3.6-bookworm` image (amd64 + arm64).

## Starting it

```bash
make up      # or: docker compose up -d db
make down    # stop, keeping data
make reset   # DESTRUCTIVE: drop the volume and all data
```

Data persists in the named Docker volume `tandem_postgres_data`, so it survives
`make down` and container rebuilds.

## Connecting

```bash
make psql    # or: docker compose exec db psql -U tandem -d tandem
```

Default local URL (from `.env.example`):

```
postgresql+psycopg://tandem:tandem@localhost:5432/tandem
```

The `+psycopg` suffix selects psycopg 3. A URL starting `postgresql://` alone
makes SQLAlchemy reach for psycopg2, which is not installed.

## Extensions

`scripts/init_postgis.sql` runs once, when the data volume is first created:

| Extension | Purpose |
| --- | --- |
| `postgis` | Geometry and geography types, spatial indexes |
| `postgis_topology` | Topology support |
| `pg_trgm` | Trigram indexes for fuzzy station-name search |

It also pins the database to UTC.

Extensions are handled here rather than in a migration on purpose: `CREATE
EXTENSION` needs superuser privileges that a migration running as an
application user will not have in a managed environment.

Verify the extension is live:

```bash
curl -s localhost:8000/health/db
# {"status":"ok","database":"reachable","postgis":"3.6 USE_GEOS=1 ..."}
```

## Migrations

Alembic reads its URL from `app.core.config`, not from `alembic.ini`, so no
credentials live in the repository.

```bash
make migrate                            # upgrade head
make migration m="add stations table"   # autogenerate a revision
make downgrade                          # roll back one revision
```

Or directly, from `backend/`:

```bash
uv run alembic upgrade head
uv run alembic revision --autogenerate -m "add stations table"
uv run alembic current
uv run alembic history --verbose
uv run alembic check      # fails if models have drifted from migrations
```

`alembic/versions/` is empty until the first model lands.

### Autogenerate rules

- A new model is only detected if its module is imported in
  `backend/app/models/__init__.py`. Autogenerate reads `Base.metadata`, and an
  unimported module is invisible to it.
- **Always read the generated migration before applying it.** Autogenerate
  misses table and column renames — it emits a drop plus an add, which loses
  the data.
- PostGIS-managed tables (`spatial_ref_sys`, `geometry_columns`,
  `geography_columns`) are excluded by `include_object` in `alembic/env.py`.
  Without that, every autogenerate would try to drop them.
- GeoAlchemy2 spatial columns need `from geoalchemy2 import Geometry` in the
  migration; add the import if it is missing.

## Conventions

- Timestamp columns are `TIMESTAMPTZ`. Use the `TimestampMixin` in
  `app/db/base.py` for `created_at` / `updated_at`.
- Geometry columns use SRID 4326 (WGS 84 lat/lon) for storage. Project to
  EPSG:2263 (NY State Plane, feet) or a metre-based CRS for distance maths —
  distances in degrees are meaningless.
- Add a GiST index to every geometry column that gets queried.
- Constraint names come from the naming convention in `app/db/base.py`, which
  keeps migrations stable and reversible.

## Troubleshooting

**Port 5432 already in use** — another Postgres is running. Stop it, or set
`POSTGRES_PORT` in `.env` to something free (e.g. `5433`).

**`password authentication failed`** — the volume was initialized with
different credentials. The `POSTGRES_*` variables only apply on first
initialization; `make reset` recreates the volume.

**`type "geometry" does not exist`** — the volume was created before the init
script existed. Run `make reset`, or enable the extension by hand:
`make psql` then `CREATE EXTENSION postgis;`.
