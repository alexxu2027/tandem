"""Record Citi Bike station availability from the live GBFS feed.

Citi Bike publishes how many bikes and docks every station has *right now*, but
it does not keep that history. This module records it: each snapshot is one row
per station, written to CSV so it opens directly in Excel or Tableau.

Uses only the Python standard library, so it runs anywhere Python 3.11+ is
installed. From the repository root:

    python -m pipelines.citibike.gbfs once
        Take one snapshot of every station.

    python -m pipelines.citibike.gbfs collect --every 5 --minutes 105
        Take a snapshot every 5 minutes for 105 minutes. Snapshots land on the
        clock (16:45, 16:50, ...), so runs on different days line up. Ctrl+C
        stops early; everything collected so far is already saved.

    python -m pipelines.citibike.gbfs combine data/processed/citibike -o rush_hour.csv
        Join the snapshots with station names, locations and capacity into one
        flat CSV for charting.

Output layout (UTC dates and times, per docs/conventions.md):

    <out>/citibike/station_status/<YYYY-MM-DD>/<HHMMSS>.csv   one file per run
    <out>/citibike/stations/<YYYY-MM-DD>.csv                  station details
    <raw>/citibike/<feed>/<YYYY-MM-DD>/<HHMMSS>.json.gz       untouched payloads

The run's start time names the status file, so a run that crosses midnight UTC
stays in the folder of the day it started.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import sys
import time
import urllib.request
from collections.abc import Iterable
from datetime import UTC, datetime
from pathlib import Path

DISCOVERY_URL = "https://gbfs.citibikenyc.com/gbfs/2.3/gbfs.json"
USER_AGENT = "tandem-collector (+https://github.com/alexxu2027/tandem)"
FEEDS = ("station_status", "station_information")

# Inactive stations report placeholder timestamps such as 86400 (1970-01-02).
# Anything before 2015 is treated as "unknown" rather than stored as a real time.
EARLIEST_REAL_TIMESTAMP = 1_420_070_400

STATUS_COLUMNS = [
    "fetched_at",  # when Tandem asked for the data
    "feed_updated_at",  # when Citi Bike last rebuilt the feed
    "station_id",
    "reported_at",  # when this station last checked in (blank if unknown)
    "bikes_available",  # classic + e-bikes ready to ride
    "ebikes_available",
    "bikes_disabled",
    "docks_available",
    "docks_disabled",
    "is_installed",
    "is_renting",
    "is_returning",
]

# A station's row is only "changed" if one of these differs. reported_at is left
# out on purpose: a station re-reporting the same counts tells the model nothing.
STATUS_VALUE_COLUMNS = STATUS_COLUMNS[4:]

STATION_COLUMNS = [
    "station_id",  # matches station_status.station_id
    "short_name",  # matches start/end_station_id in the trip history files
    "name",
    "lat",
    "lon",
    "capacity",
    "region_id",
    "last_seen_at",
]

COMBINED_COLUMNS = [
    "fetched_at",
    "fetched_at_new_york",
    *[c for c in STATION_COLUMNS if c != "last_seen_at"],
    *STATUS_COLUMNS[3:],
]


# ---------------------------------------------------------------------------
# Fetching
# ---------------------------------------------------------------------------


def fetch_json(url: str, attempts: int = 3) -> tuple[dict, bytes]:
    """Download a JSON document, retrying briefly on network errors."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read()
            return json.loads(body), body
        except (OSError, ValueError) as error:
            if attempt == attempts:
                raise
            print(f"  fetch failed ({error}); retrying", file=sys.stderr)
            time.sleep(5 * attempt)
    raise AssertionError("unreachable")


def feed_urls() -> dict[str, str]:
    """Look up the current feed URLs; Citi Bike moves them occasionally."""
    discovery, _ = fetch_json(DISCOVERY_URL)
    feeds = discovery["data"]["en"]["feeds"]
    return {feed["name"]: feed["url"] for feed in feeds if feed["name"] in FEEDS}


# ---------------------------------------------------------------------------
# Normalising
# ---------------------------------------------------------------------------


def iso_utc(moment: datetime) -> str:
    return moment.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def epoch_to_iso(value: object) -> str:
    """Convert a GBFS epoch timestamp to ISO 8601 UTC, or "" if it is a placeholder."""
    if not isinstance(value, int | float) or value < EARLIEST_REAL_TIMESTAMP:
        return ""
    return iso_utc(datetime.fromtimestamp(value, UTC))


def status_rows(payload: dict, fetched_at: datetime) -> list[dict]:
    """Flatten a station_status payload into one row per station."""
    fetched = iso_utc(fetched_at)
    feed_updated = epoch_to_iso(payload.get("last_updated"))
    rows = []
    for station in payload["data"]["stations"]:
        rows.append(
            {
                "fetched_at": fetched,
                "feed_updated_at": feed_updated,
                "station_id": station["station_id"],
                "reported_at": epoch_to_iso(station.get("last_reported")),
                "bikes_available": station.get("num_bikes_available", ""),
                "ebikes_available": station.get("num_ebikes_available", ""),
                "bikes_disabled": station.get("num_bikes_disabled", ""),
                "docks_available": station.get("num_docks_available", ""),
                "docks_disabled": station.get("num_docks_disabled", ""),
                "is_installed": station.get("is_installed", ""),
                "is_renting": station.get("is_renting", ""),
                "is_returning": station.get("is_returning", ""),
            }
        )
    return rows


def station_rows(payload: dict, fetched_at: datetime) -> list[dict]:
    """Flatten a station_information payload into one row per station."""
    seen = iso_utc(fetched_at)
    return [
        {
            "station_id": station["station_id"],
            "short_name": station.get("short_name", ""),
            "name": station.get("name", ""),
            "lat": station.get("lat", ""),
            "lon": station.get("lon", ""),
            "capacity": station.get("capacity", ""),
            "region_id": station.get("region_id", ""),
            "last_seen_at": seen,
        }
        for station in payload["data"]["stations"]
    ]


def changed_rows(rows: list[dict], previous: dict[str, tuple]) -> list[dict]:
    """Keep only stations whose counts or flags differ from the last snapshot.

    ``previous`` maps station_id to its last values and is updated in place. A
    station missing from a later file has not changed: carry its last row forward.
    """
    kept = []
    for row in rows:
        values = tuple(row[column] for column in STATUS_VALUE_COLUMNS)
        if previous.get(row["station_id"]) != values:
            previous[row["station_id"]] = values
            kept.append(row)
    return kept


# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------


def append_csv(path: Path, rows: Iterable[dict], columns: list[str]) -> None:
    """Append rows, writing the header first if the file is new."""
    path.parent.mkdir(parents=True, exist_ok=True)
    is_new = not path.exists()
    with path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        if is_new:
            writer.writeheader()
        writer.writerows(rows)


def read_csv(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def merge_stations(path: Path, rows: list[dict]) -> None:
    """Update the day's station file, keeping stations that have since disappeared."""
    merged = {row["station_id"]: row for row in read_csv(path)} if path.exists() else {}
    merged.update({str(row["station_id"]): row for row in rows})
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=STATION_COLUMNS)
        writer.writeheader()
        writer.writerows(sorted(merged.values(), key=lambda row: row["station_id"]))


def save_raw(raw_dir: Path, feed: str, fetched_at: datetime, body: bytes) -> None:
    folder = raw_dir / "citibike" / feed / fetched_at.strftime("%Y-%m-%d")
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{fetched_at:%H%M%S}.json.gz").write_bytes(gzip.compress(body))


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------


class Run:
    """One collection run: a single status file plus that day's station file."""

    def __init__(self, out_dir: Path, raw_dir: Path | None, changes_only: bool) -> None:
        started = datetime.now(UTC)
        day = started.strftime("%Y-%m-%d")
        self.status_path = out_dir / "citibike" / "station_status" / day / f"{started:%H%M%S}.csv"
        self.stations_path = out_dir / "citibike" / "stations" / f"{day}.csv"
        self.raw_dir = raw_dir
        self.changes_only = changes_only
        self.previous: dict[str, tuple] = {}
        self.urls = feed_urls()

    def snapshot(self) -> int:
        """Fetch both feeds once and save them. Returns the number of rows written."""
        fetched_at = datetime.now(UTC)
        status, status_body = fetch_json(self.urls["station_status"])
        info, info_body = fetch_json(self.urls["station_information"])
        if self.raw_dir:
            save_raw(self.raw_dir, "station_status", fetched_at, status_body)
            save_raw(self.raw_dir, "station_information", fetched_at, info_body)

        rows = status_rows(status, fetched_at)
        if self.changes_only:
            rows = changed_rows(rows, self.previous)
        append_csv(self.status_path, rows, STATUS_COLUMNS)
        merge_stations(self.stations_path, station_rows(info, fetched_at))
        return len(rows)


def next_mark(now: datetime, every_minutes: int) -> datetime:
    """The next clock time that is a whole multiple of ``every_minutes``."""
    step = every_minutes * 60
    return datetime.fromtimestamp((int(now.timestamp()) // step + 1) * step, UTC)


def collect(run: Run, every_minutes: int, total_minutes: float) -> None:
    deadline = time.time() + total_minutes * 60
    while True:
        mark = next_mark(datetime.now(UTC), every_minutes)
        if mark.timestamp() >= deadline:
            break
        wait = mark.timestamp() - time.time()
        print(f"Next snapshot at {mark:%H:%M} UTC (in {wait / 60:.1f} min)", flush=True)
        time.sleep(max(0.0, wait))
        try:
            written = run.snapshot()
        except (OSError, ValueError, KeyError) as error:
            # One bad fetch should not end a long run; the next mark tries again.
            print(f"  snapshot failed: {error}", file=sys.stderr, flush=True)
            continue
        print(f"  saved {written} rows to {run.status_path}", flush=True)


def combine(source: Path, output: Path) -> int:
    """Join every status file under ``source`` with station details into one CSV."""
    try:
        from zoneinfo import ZoneInfo

        new_york = ZoneInfo("America/New_York")
    except (ImportError, LookupError):
        # Windows without the tzdata package has no time zone database.
        new_york = None
        print("No time zone data; fetched_at_new_york will be blank.", file=sys.stderr)

    stations: dict[str, dict] = {}
    for path in sorted((source / "stations").glob("*.csv")):
        stations.update({row["station_id"]: row for row in read_csv(path)})

    count = 0
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=COMBINED_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        for path in sorted((source / "station_status").rglob("*.csv")):
            for row in read_csv(path):
                fetched = datetime.strptime(row["fetched_at"], "%Y-%m-%dT%H:%M:%SZ")
                local = fetched.replace(tzinfo=UTC).astimezone(new_york) if new_york else None
                writer.writerow(
                    {
                        **stations.get(row["station_id"], {}),
                        **row,
                        "fetched_at_new_york": f"{local:%Y-%m-%d %H:%M:%S}" if local else "",
                    }
                )
                count += 1
    return count


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)

    def add_output_options(command: argparse.ArgumentParser) -> None:
        command.add_argument("--out", type=Path, default=Path("data/processed"))
        command.add_argument("--raw", type=Path, default=Path("data/raw"))
        command.add_argument("--no-raw", action="store_true", help="skip saving raw JSON")

    once = commands.add_parser("once", help="take one snapshot")
    add_output_options(once)

    repeat = commands.add_parser("collect", help="take snapshots on a schedule")
    add_output_options(repeat)
    repeat.add_argument("--every", type=int, default=5, help="minutes between snapshots")
    repeat.add_argument("--minutes", type=float, required=True, help="how long to run")
    repeat.add_argument(
        "--changes-only",
        action="store_true",
        help="after the first snapshot, only write stations whose numbers changed",
    )

    joined = commands.add_parser("combine", help="join snapshots into one flat CSV")
    joined.add_argument("source", type=Path, help="e.g. data/processed/citibike")
    joined.add_argument("-o", "--output", type=Path, required=True)

    args = parser.parse_args(argv)

    if args.command == "combine":
        count = combine(args.source, args.output)
        print(f"Wrote {count} rows to {args.output}")
        return

    raw_dir = None if args.no_raw else args.raw
    run = Run(args.out, raw_dir, changes_only=getattr(args, "changes_only", False))
    if args.command == "once":
        print(f"Saved {run.snapshot()} rows to {run.status_path}")
    else:
        try:
            collect(run, args.every, args.minutes)
        except KeyboardInterrupt:
            print("\nStopped. Everything collected so far is saved.")
        print(f"Station details: {run.stations_path}")


if __name__ == "__main__":
    main()
