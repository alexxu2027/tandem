# Tandem database skeleton

Assignment: **Deployed database skeleton**, due Thu Oct 22 2026, 12 PM.

This is the standalone class exercise (Railway + psycopg2, like the deploy lab). It's separate from the backend's Alembic/PostGIS setup and doesn't touch it. The sample CSV lives here because the repo ignores `*.csv` everywhere except `docs/`.

Run everything from inside this folder: `cd docs/db-skeleton`.

Submit on Brightspace (one submission for the group):
1. A screenshot of the tables in Railway (Postgres service, **Data** tab)
2. `schema.sql`

Don't put the Railway URL in Brightspace, the repo, or any chat. It only goes in `.env`.

## What's in here

| File | What it does |
|---|---|
| `schema.sql` | CREATE statements, the file you submit |
| `load_data.py` | Runs the schema on Railway and loads the CSV, then prints row counts |
| `queries.py` | A few test queries (step 1d of the lab) |
| `data/citibike_rush_hour_sample.csv` | Last week's sample: 6 stations, 5-min snapshots, Oct 14 4:05 to 6:00 PM |

## Schema

```
regions 1--N stations 1--N station_status        <- real data (144 rows)
users 1--N trips --> stations (destination)      <- placeholders
trips 1--N dock_predictions --> stations
trips 1--N reroutes --> stations (from, to)
weather_hourly                                   <- placeholder, forecast input
```

- The CSV repeats station info on every row, so it's split into `stations` (6 rows) and `station_status` (144 rows, one per station per pull).
- `station_status` is unique on (station, fetched_at), has a check that e-bikes are never more than total bikes, and has an index for "dock history at station X".
- `fetched_at_new_york` isn't stored since it's just `fetched_at` in NY time.
- Placeholders follow the roadmap: trips (routing + ETA), dock_predictions (LightGBM forecast), reroutes (automatic rerouting), weather (forecast input).

## Deploy steps (same as the class lab)

1. Railway: **New Project → Deploy PostgreSQL**
2. Postgres service → **Connect → Public Network → Add Public Access**, then deploy the change
3. Variables tab: copy `DATABASE_PUBLIC_URL`
4. Here: copy `.env.example` to `.env`, paste it as `DATABASE_URL=...`
5. Run:
   ```
   pip install -r requirements.txt
   python load_data.py
   python queries.py
   ```
   Expected counts: regions 1, stations 6, station_status 144, everything else 0
6. Railway → Postgres → **Data** tab → screenshot the table list (and maybe open `station_status`)

Tested on a local Postgres: loads cleanly, re-runs cleanly, and the queries return the expected results.
