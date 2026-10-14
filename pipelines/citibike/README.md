# Citi Bike station availability

Citi Bike shows how many bikes and docks each station has **right now**, but it
does not keep a history. Tandem's model needs that history, so we record it
ourselves with [`gbfs.py`](gbfs.py).

## Where the data comes from

Citi Bike's public live feed (GBFS). No account or API key needed.

| Feed | What it contains |
| --- | --- |
| `station_status` | Bikes, e-bikes and docks available at every station, refreshed every minute |
| `station_information` | Station name, location, capacity |

## Collecting data yourself

You need Python 3.11 or newer and nothing else. From the repository root:

```bash
# One snapshot of all ~2,500 stations (takes a few seconds)
python -m pipelines.citibike.gbfs once

# A snapshot every 5 minutes for 1 hour 45 minutes (e.g. 4:45pm to 6:30pm)
python -m pipelines.citibike.gbfs collect --every 5 --minutes 105

# Join everything into one CSV with station names, for Excel or Tableau
python -m pipelines.citibike.gbfs combine data/processed/citibike -o citibike.csv
```

Keep the laptop awake and online while `collect` runs. Ctrl+C stops it early;
anything already collected is saved.

Files land in `data/` (not committed to git):

| Path | Contents |
| --- | --- |
| `data/processed/citibike/station_status/<date>/<time>.csv` | One row per station per snapshot |
| `data/processed/citibike/stations/<date>.csv` | Station names, locations, capacity |
| `data/raw/citibike/...json.gz` | The untouched feed responses |

## Automatic collection

[`.github/workflows/collect-citibike.yml`](../../.github/workflows/collect-citibike.yml)
runs continuously on GitHub Actions and saves to
[alexxu2027/tandem-data](https://github.com/alexxu2027/tandem-data). Each run
collects for about an hour, saves, then starts the next run. You can watch the
runs in this repository's **Actions** tab.

**It keeps running until someone turns it off.** To stop it: Actions tab →
"Collect Citi Bike availability" → "..." menu → **Disable workflow**. To restart:
enable it, then click **Run workflow**. If runs start failing (GitHub emails you
about each one), disable it until it's fixed.

It uses `--changes-only`: after the first snapshot in each file, a station only
gets a new row when its numbers change. To get a station's availability at any
moment, take its most recent row at or before that moment.

## Columns

All times are UTC (New York is UTC−4 in summer, UTC−5 in winter). The `combine`
output adds a `fetched_at_new_york` column for convenience.

**station_status**

| Column | Meaning |
| --- | --- |
| `fetched_at` | When we downloaded the snapshot |
| `feed_updated_at` | When Citi Bike last refreshed the feed |
| `station_id` | Joins to `stations.station_id` |
| `reported_at` | When the station last checked in. Blank for inactive stations |
| `bikes_available` | Bikes ready to ride, classic and electric combined |
| `ebikes_available` | The electric share of `bikes_available` |
| `bikes_disabled` / `docks_disabled` | Broken bikes or docks |
| `docks_available` | Empty docks you can return a bike to |
| `is_installed` / `is_renting` / `is_returning` | 1 if true, 0 if not |

**stations**

| Column | Meaning |
| --- | --- |
| `station_id` | Live-feed ID (a long number or a UUID) |
| `short_name` | e.g. `5329.03`. This is what the trip history files call `start_station_id` / `end_station_id` |
| `name`, `lat`, `lon` | Station name and location |
| `capacity` | Total docks. 0 for inactive stations |
| `region_id` | `71` New York City, `70` Jersey City, `311` Hoboken |
| `last_seen_at` | Last time the station appeared in the feed that day |
