# Pipelines

Data ingestion. One package per external source. **Nothing here is implemented
yet** — these are placeholders that fix the module boundaries before the code
arrives.

| Package | Source | Status |
| --- | --- | --- |
| `citibike/` | GBFS real-time feeds + historical trip archives | Placeholder |
| `weather/` | NYC observations and short-range forecasts | Placeholder |
| `nyc_open_data/` | Bike lanes, street centrelines (Socrata) | Placeholder |
| `incidents/` | Service alerts, closures, collisions | Placeholder |

## Contract

Every pipeline follows the same three stages:

1. **Fetch** — write the untouched payload to `data/raw/<source>/<dataset>/<utc-date>/`.
2. **Normalise** — transform into the Tandem schema, write to `data/processed/`.
3. **Load** — upsert into PostgreSQL.

Keeping the raw payload means a schema change can be replayed without re-fetching.

## Rules

- Convert every timestamp to UTC at ingestion. A source reporting local New
  York time is converted immediately; the local value is never stored.
- Credentials come from environment variables (see `.env.example`), never from
  code or notebooks.
- Fetching is idempotent and re-runnable for a given time window.
- Respect source rate limits and cache aggressively; GBFS feeds publish a
  `ttl` that says how long a response stays valid.
