-- Tandem: preliminary database schema (PostgreSQL / Railway)
-- PiPAI Fall 2026 002, Group 3
--
-- Loaded with real data:  regions, stations, station_status
--   (from data/citibike_rush_hour_sample.csv, Citi Bike GBFS feed, Oct 14 2026 4:05-6:00 PM)
-- Placeholders for later builds: users, trips, dock_predictions, reroutes, weather_hourly
--
-- Design rules applied: entity -> table, 1:N -> foreign key, M:N -> bridge table.
-- The CSV repeats station info on every row, so it is split into a stations table (one row per
-- station) and a station_status table (one row per station per 5-minute snapshot).
-- fetched_at_new_york is not stored; it is fetched_at shown in America/New_York and can be derived.

-- Tables are dropped children-first so the script can be re-run.
DROP TABLE IF EXISTS reroutes;
DROP TABLE IF EXISTS dock_predictions;
DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS weather_hourly;
DROP TABLE IF EXISTS station_status;
DROP TABLE IF EXISTS stations;
DROP TABLE IF EXISTS regions;

-- ---------------------------------------------------------------------------
-- Real data (from the Citi Bike live feed)
-- ---------------------------------------------------------------------------

-- Citi Bike service region (region 71 = NYC in our sample)
CREATE TABLE regions (
    region_id   INTEGER PRIMARY KEY,
    name        TEXT
);

-- One row per dock station. Static info that the CSV repeated on every snapshot.
CREATE TABLE stations (
    station_id  TEXT PRIMARY KEY,              -- GBFS id (UUID or long numeric string)
    short_name  TEXT UNIQUE,                   -- e.g. 6765.01
    name        TEXT NOT NULL,                 -- e.g. 12 Ave & W 40 St
    lat         DOUBLE PRECISION NOT NULL,
    lon         DOUBLE PRECISION NOT NULL,
    capacity    INTEGER NOT NULL CHECK (capacity > 0),
    region_id   INTEGER REFERENCES regions(region_id)
);

-- One row per station per feed pull (every 5 minutes). Station 1:N station_status.
CREATE TABLE station_status (
    status_id         BIGSERIAL PRIMARY KEY,
    station_id        TEXT NOT NULL REFERENCES stations(station_id),
    fetched_at        TIMESTAMPTZ NOT NULL,    -- when we pulled the feed
    reported_at       TIMESTAMPTZ NOT NULL,    -- when the station last reported to Citi Bike
    bikes_available   INTEGER NOT NULL CHECK (bikes_available >= 0),
    ebikes_available  INTEGER NOT NULL CHECK (ebikes_available >= 0),
    bikes_disabled    INTEGER NOT NULL CHECK (bikes_disabled >= 0),
    docks_available   INTEGER NOT NULL CHECK (docks_available >= 0),
    docks_disabled    INTEGER NOT NULL CHECK (docks_disabled >= 0),
    is_installed      BOOLEAN NOT NULL,
    is_renting        BOOLEAN NOT NULL,
    is_returning      BOOLEAN NOT NULL,
    CHECK (ebikes_available <= bikes_available),   -- e-bikes are counted inside bikes_available
    UNIQUE (station_id, fetched_at)                -- one snapshot per station per pull
);

-- Main query pattern: "dock history for station X over time"
CREATE INDEX idx_station_status_station_time ON station_status (station_id, fetched_at);

-- ---------------------------------------------------------------------------
-- Placeholders (empty for now, shaped by the roadmap)
-- ---------------------------------------------------------------------------

-- Riders using the app
CREATE TABLE users (
    user_id     BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT UNIQUE NOT NULL,
    age         INTEGER CHECK (age > 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A ride a user starts in the app (build 2: routing + ETA). User 1:N trips.
CREATE TABLE trips (
    trip_id                 BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT NOT NULL REFERENCES users(user_id),
    origin_lat              DOUBLE PRECISION,
    origin_lon              DOUBLE PRECISION,
    destination_station_id  TEXT REFERENCES stations(station_id),
    started_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    eta                     TIMESTAMPTZ,
    ended_at                TIMESTAMPTZ,
    status                  TEXT NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active', 'completed', 'cancelled'))
);

-- Model output: will a dock be open at this station when the rider arrives? (build 3)
CREATE TABLE dock_predictions (
    prediction_id              BIGSERIAL PRIMARY KEY,
    station_id                 TEXT NOT NULL REFERENCES stations(station_id),
    trip_id                    BIGINT REFERENCES trips(trip_id),   -- NULL for batch forecasts
    predicted_for              TIMESTAMPTZ NOT NULL,               -- the arrival time being forecast
    predicted_docks_available  NUMERIC(6,2),
    prob_dock_available        NUMERIC(4,3) CHECK (prob_dock_available BETWEEN 0 AND 1),
    model_version              TEXT,                               -- e.g. lightgbm-v0
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Automatic rerouting events (build 4): trip switched from one station to a backup.
CREATE TABLE reroutes (
    reroute_id       BIGSERIAL PRIMARY KEY,
    trip_id          BIGINT NOT NULL REFERENCES trips(trip_id),
    from_station_id  TEXT NOT NULL REFERENCES stations(station_id),
    to_station_id    TEXT NOT NULL REFERENCES stations(station_id),
    reason           TEXT,                                          -- e.g. predicted_full
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (from_station_id <> to_station_id)
);

-- Hourly weather, an input to the dock forecast
CREATE TABLE weather_hourly (
    observed_at     TIMESTAMPTZ PRIMARY KEY,
    temp_f          NUMERIC(5,1),
    precip_in       NUMERIC(5,2),
    wind_mph        NUMERIC(5,1)
);
