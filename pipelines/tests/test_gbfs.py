"""Tests for the GBFS collector. No network: payloads are built inline."""

from datetime import UTC, datetime

from pipelines.citibike import gbfs

FETCHED = datetime(2026, 10, 14, 21, 0, 5, tzinfo=UTC)


def status_payload(*stations: dict) -> dict:
    return {"last_updated": 1792015200, "ttl": 60, "data": {"stations": list(stations)}}


def station(station_id: str, bikes: int, last_reported: int = 1792015100) -> dict:
    return {
        "station_id": station_id,
        "num_bikes_available": bikes,
        "num_ebikes_available": 1,
        "num_bikes_disabled": 0,
        "num_docks_available": 10 - bikes,
        "num_docks_disabled": 0,
        "is_installed": 1,
        "is_renting": 1,
        "is_returning": 1,
        "last_reported": last_reported,
    }


def test_status_rows_flatten_and_use_utc():
    [row] = gbfs.status_rows(status_payload(station("a", 4)), FETCHED)
    assert row["fetched_at"] == "2026-10-14T21:00:05Z"
    assert row["feed_updated_at"] == "2026-10-14T22:00:00Z"
    assert row["reported_at"] == "2026-10-14T21:58:20Z"
    assert row["bikes_available"] == 4
    assert row["docks_available"] == 6


def test_placeholder_timestamps_become_blank():
    [row] = gbfs.status_rows(status_payload(station("dead", 0, last_reported=86400)), FETCHED)
    assert row["reported_at"] == ""


def test_changed_rows_drops_repeats_but_not_real_changes():
    previous: dict = {}
    first = gbfs.status_rows(status_payload(station("a", 4), station("b", 2)), FETCHED)
    assert len(gbfs.changed_rows(first, previous)) == 2

    # "a" re-reports the same counts at a new time; "b" loses a bike.
    later = gbfs.status_rows(
        status_payload(station("a", 4, last_reported=1792015400), station("b", 1)), FETCHED
    )
    assert [row["station_id"] for row in gbfs.changed_rows(later, previous)] == ["b"]


def test_merge_stations_keeps_stations_that_disappear(tmp_path):
    path = tmp_path / "stations.csv"
    info = {"data": {"stations": [{"station_id": "a", "name": "Old"}, {"station_id": "b"}]}}
    gbfs.merge_stations(path, gbfs.station_rows(info, FETCHED))

    info = {"data": {"stations": [{"station_id": "a", "name": "New"}]}}
    gbfs.merge_stations(path, gbfs.station_rows(info, FETCHED))

    rows = {row["station_id"]: row for row in gbfs.read_csv(path)}
    assert set(rows) == {"a", "b"}
    assert rows["a"]["name"] == "New"


def test_next_mark_lands_on_the_clock():
    now = datetime(2026, 10, 14, 20, 52, 30, tzinfo=UTC)
    assert gbfs.next_mark(now, 5) == datetime(2026, 10, 14, 20, 55, tzinfo=UTC)
    on_mark = datetime(2026, 10, 14, 20, 55, tzinfo=UTC)
    assert gbfs.next_mark(on_mark, 5) == datetime(2026, 10, 14, 21, 0, tzinfo=UTC)


def test_combine_joins_station_details(tmp_path):
    source = tmp_path / "citibike"
    gbfs.append_csv(
        source / "station_status" / "2026-10-14" / "210005.csv",
        gbfs.status_rows(status_payload(station("a", 4)), FETCHED),
        gbfs.STATUS_COLUMNS,
    )
    info = {"data": {"stations": [{"station_id": "a", "name": "W 4 St", "capacity": 10}]}}
    gbfs.merge_stations(source / "stations" / "2026-10-14.csv", gbfs.station_rows(info, FETCHED))

    output = tmp_path / "combined.csv"
    assert gbfs.combine(source, output) == 1
    [row] = gbfs.read_csv(output)
    assert row["name"] == "W 4 St"
    assert row["capacity"] == "10"
    assert row["bikes_available"] == "4"
