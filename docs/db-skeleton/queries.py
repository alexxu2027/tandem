"""Base queries against the Tandem database (step 1d of the deploy lab).

Usage:  python queries.py
"""
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

QUERIES = {
    "Snapshot count (must match the CSV's 144 rows)":
        "SELECT count(*) FROM station_status",

    "Stations":
        "SELECT short_name, name, capacity FROM stations ORDER BY name",

    "Docks open at each station, first vs last snapshot":
        """SELECT s.name,
                  min(st.docks_available) FILTER (WHERE st.fetched_at = b.first_at) AS docks_at_4pm,
                  min(st.docks_available) FILTER (WHERE st.fetched_at = b.last_at)  AS docks_at_6pm
           FROM station_status st
           JOIN stations s USING (station_id)
           CROSS JOIN (SELECT min(fetched_at) AS first_at, max(fetched_at) AS last_at
                       FROM station_status) b
           GROUP BY s.name
           ORDER BY docks_at_6pm""",

    "Minutes each station spent with 2 or fewer open docks (5-min snapshots)":
        """SELECT s.name, 5 * count(*) AS minutes_nearly_full
           FROM station_status st
           JOIN stations s USING (station_id)
           WHERE st.docks_available <= 2
           GROUP BY s.name
           ORDER BY minutes_nearly_full DESC""",
}


def main():
    load_dotenv(Path(__file__).parent / ".env")
    conn = psycopg2.connect(os.environ["DATABASE_URL"])
    with conn, conn.cursor() as cur:
        for title, sql in QUERIES.items():
            cur.execute(sql)
            print(f"\n-- {title}")
            for row in cur.fetchall():
                print("  ", *row)
    conn.close()


if __name__ == "__main__":
    main()
