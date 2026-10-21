"""Create the Tandem schema on the Postgres at DATABASE_URL and load the Citi Bike sample.

Usage:  python load_data.py
Reads DATABASE_URL from .env (use Railway's DATABASE_PUBLIC_URL when running from a laptop).
"""
import csv
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

HERE = Path(__file__).parent
SCHEMA = HERE / "schema.sql"
CSV_PATH = HERE / "data" / "citibike_rush_hour_sample.csv"
TABLES = ["regions", "stations", "station_status",
          "users", "trips", "dock_predictions", "reroutes", "weather_hourly"]


def main():
    load_dotenv(HERE / ".env")
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL not set. Copy .env.example to .env and paste Railway's DATABASE_PUBLIC_URL.")

    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    conn = psycopg2.connect(url)
    with conn, conn.cursor() as cur:
        # 1. Structure first (parents before children)
        cur.execute(SCHEMA.read_text(encoding="utf-8"))

        # 2. Regions and stations: one row each, deduplicated from the snapshots
        for region_id in sorted({int(r["region_id"]) for r in rows}):
            cur.execute("INSERT INTO regions (region_id, name) VALUES (%s, %s)",
                        (region_id, "NYC" if region_id == 71 else None))

        stations = {r["station_id"]: r for r in rows}
        for s in stations.values():
            cur.execute(
                """INSERT INTO stations (station_id, short_name, name, lat, lon, capacity, region_id)
                   VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (s["station_id"], s["short_name"], s["name"], float(s["lat"]), float(s["lon"]),
                 int(s["capacity"]), int(s["region_id"])))

        # 3. Snapshots
        for r in rows:
            cur.execute(
                """INSERT INTO station_status
                   (station_id, fetched_at, reported_at, bikes_available, ebikes_available,
                    bikes_disabled, docks_available, docks_disabled,
                    is_installed, is_renting, is_returning)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (r["station_id"], r["fetched_at"], r["reported_at"],
                 int(r["bikes_available"]), int(r["ebikes_available"]), int(r["bikes_disabled"]),
                 int(r["docks_available"]), int(r["docks_disabled"]),
                 r["is_installed"] == "1", r["is_renting"] == "1", r["is_returning"] == "1"))

        print(f"CSV rows: {len(rows)}")
        for t in TABLES:
            cur.execute(f"SELECT count(*) FROM {t}")
            print(f"{t:18} {cur.fetchone()[0]}")
    conn.close()


if __name__ == "__main__":
    main()
