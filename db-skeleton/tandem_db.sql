-- Tandem: preliminary database schema (PostgreSQL / Railway)
-- PiPAI Fall 2026 002, Group 3
--
-- Standalone file: run it in any Postgres (psql -f tandem_db.sql) to create every table and
-- load last week's Citi Bike sample. Safe to re-run (drops and recreates the tables).
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

-- ---------------------------------------------------------------------------
-- Sample data: data/citibike_rush_hour_sample.csv (144 rows)
-- ---------------------------------------------------------------------------

INSERT INTO regions (region_id, name) VALUES (71, 'NYC');

INSERT INTO stations (station_id, short_name, name, lat, lon, capacity, region_id) VALUES
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '6765.01', '12 Ave & W 40 St', 40.76087502, -74.00277668, 76, 71),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '6474.11', 'E 40 St & 5 Ave', 40.752062307, -73.9816324043, 93, 71),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '6230.04', 'FDR Drive & E 35 St', 40.744219, -73.97121214, 123, 71),
    ('2241933651126795842', '5847.10', 'Greenwich St & Christopher St', 40.7326, -74.00767, 74, 71),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '6578.01', 'W 34 St & 11 Ave', 40.75594159, -74.0021163, 80, 71),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '6740.10', 'W 51 St & 6 Ave', 40.7606597, -73.98042047, 81, 71);

INSERT INTO station_status (station_id, fetched_at, reported_at, bikes_available, ebikes_available, bikes_disabled, docks_available, docks_disabled, is_installed, is_renting, is_returning) VALUES
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:05:00Z', '2026-10-14T20:03:35Z', 15, 4, 4, 55, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:10:00Z', '2026-10-14T20:07:50Z', 18, 7, 4, 53, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:15:00Z', '2026-10-14T20:13:40Z', 16, 5, 4, 55, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:20:00Z', '2026-10-14T20:18:24Z', 18, 6, 4, 52, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:25:00Z', '2026-10-14T20:23:42Z', 22, 11, 5, 47, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:30:00Z', '2026-10-14T20:28:09Z', 27, 16, 5, 44, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:35:00Z', '2026-10-14T20:33:27Z', 28, 16, 5, 43, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:40:00Z', '2026-10-14T20:38:31Z', 30, 15, 5, 42, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:45:00Z', '2026-10-14T20:43:36Z', 35, 19, 5, 35, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:50:00Z', '2026-10-14T20:48:28Z', 40, 24, 5, 31, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:55:00Z', '2026-10-14T20:53:45Z', 36, 21, 6, 35, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:00:00Z', '2026-10-14T20:58:39Z', 35, 21, 5, 36, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:05:00Z', '2026-10-14T21:03:44Z', 39, 26, 5, 32, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:10:00Z', '2026-10-14T21:08:48Z', 49, 33, 5, 20, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:15:00Z', '2026-10-14T21:13:11Z', 48, 30, 5, 24, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:20:00Z', '2026-10-14T21:18:32Z', 51, 30, 5, 20, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:25:00Z', '2026-10-14T21:23:20Z', 57, 32, 6, 12, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:30:00Z', '2026-10-14T21:28:46Z', 64, 36, 5, 5, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:35:00Z', '2026-10-14T21:33:43Z', 65, 36, 5, 7, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:40:00Z', '2026-10-14T21:38:47Z', 67, 39, 5, 4, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:45:00Z', '2026-10-14T21:42:29Z', 68, 38, 5, 3, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:50:00Z', '2026-10-14T21:48:35Z', 69, 39, 5, 2, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:55:00Z', '2026-10-14T21:53:43Z', 67, 39, 5, 2, 0, TRUE, TRUE, TRUE),
    ('66dc7d58-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T22:00:00Z', '2026-10-14T21:58:44Z', 67, 39, 6, 2, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:05:00Z', '2026-10-14T20:03:48Z', 79, 70, 7, 6, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:10:00Z', '2026-10-14T20:08:17Z', 76, 68, 7, 10, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:15:00Z', '2026-10-14T20:13:44Z', 72, 64, 7, 14, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:20:00Z', '2026-10-14T20:18:48Z', 67, 60, 7, 21, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:25:00Z', '2026-10-14T20:23:47Z', 63, 57, 7, 24, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:30:00Z', '2026-10-14T20:28:18Z', 61, 56, 7, 24, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:35:00Z', '2026-10-14T20:32:41Z', 60, 55, 7, 24, 1, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:40:00Z', '2026-10-14T20:38:46Z', 60, 56, 7, 27, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:45:00Z', '2026-10-14T20:42:53Z', 59, 56, 7, 27, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:50:00Z', '2026-10-14T20:47:59Z', 56, 53, 7, 30, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:55:00Z', '2026-10-14T20:53:46Z', 58, 51, 7, 28, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:00:00Z', '2026-10-14T20:58:17Z', 55, 51, 7, 31, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:05:00Z', '2026-10-14T21:03:48Z', 51, 46, 7, 35, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:10:00Z', '2026-10-14T21:08:30Z', 49, 45, 7, 38, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:15:00Z', '2026-10-14T21:13:21Z', 46, 44, 8, 41, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:20:00Z', '2026-10-14T21:18:45Z', 39, 37, 9, 47, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:25:00Z', '2026-10-14T21:23:46Z', 33, 30, 7, 51, 1, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:30:00Z', '2026-10-14T21:28:48Z', 32, 31, 8, 52, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:35:00Z', '2026-10-14T21:33:36Z', 24, 23, 10, 61, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:40:00Z', '2026-10-14T21:38:47Z', 21, 18, 9, 61, 1, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:45:00Z', '2026-10-14T21:43:46Z', 19, 17, 9, 65, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:50:00Z', '2026-10-14T21:48:44Z', 10, 10, 10, 73, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:55:00Z', '2026-10-14T21:53:36Z', 11, 9, 9, 72, 0, TRUE, TRUE, TRUE),
    ('66db30e0-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T22:00:00Z', '2026-10-14T21:58:45Z', 10, 5, 9, 73, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:05:00Z', '2026-10-14T20:03:41Z', 3, 2, 2, 118, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:10:00Z', '2026-10-14T20:07:44Z', 6, 3, 2, 115, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:15:00Z', '2026-10-14T20:13:48Z', 9, 6, 2, 111, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:20:00Z', '2026-10-14T20:18:44Z', 17, 14, 3, 103, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:25:00Z', '2026-10-14T20:23:38Z', 36, 30, 2, 85, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:30:00Z', '2026-10-14T20:28:40Z', 37, 29, 2, 84, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:35:00Z', '2026-10-14T20:33:42Z', 35, 27, 2, 87, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:40:00Z', '2026-10-14T20:38:38Z', 31, 24, 2, 89, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:45:00Z', '2026-10-14T20:43:19Z', 32, 25, 2, 88, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:50:00Z', '2026-10-14T20:48:14Z', 30, 22, 2, 91, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:55:00Z', '2026-10-14T20:52:35Z', 32, 23, 2, 89, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:00:00Z', '2026-10-14T20:58:43Z', 36, 25, 2, 84, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:05:00Z', '2026-10-14T21:03:35Z', 42, 30, 2, 78, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:10:00Z', '2026-10-14T21:08:45Z', 50, 35, 2, 70, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:15:00Z', '2026-10-14T21:12:31Z', 48, 35, 2, 73, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:20:00Z', '2026-10-14T21:18:36Z', 49, 36, 2, 74, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:25:00Z', '2026-10-14T21:22:39Z', 50, 37, 2, 71, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:30:00Z', '2026-10-14T21:28:44Z', 52, 38, 3, 68, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:35:00Z', '2026-10-14T21:32:46Z', 61, 45, 2, 60, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:40:00Z', '2026-10-14T21:38:44Z', 60, 44, 2, 62, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:45:00Z', '2026-10-14T21:43:47Z', 60, 42, 2, 59, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:50:00Z', '2026-10-14T21:47:27Z', 66, 48, 2, 55, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:55:00Z', '2026-10-14T21:53:46Z', 74, 55, 3, 46, 0, TRUE, TRUE, TRUE),
    ('66dc7659-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T22:00:00Z', '2026-10-14T21:58:23Z', 77, 58, 2, 44, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:05:00Z', '2026-10-14T20:03:47Z', 25, 16, 3, 40, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:10:00Z', '2026-10-14T20:08:41Z', 25, 16, 3, 39, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:15:00Z', '2026-10-14T20:13:48Z', 28, 18, 3, 37, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:20:00Z', '2026-10-14T20:18:47Z', 31, 20, 3, 34, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:25:00Z', '2026-10-14T20:23:48Z', 30, 19, 4, 35, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:30:00Z', '2026-10-14T20:28:44Z', 32, 21, 3, 33, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:35:00Z', '2026-10-14T20:33:47Z', 32, 21, 3, 33, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:40:00Z', '2026-10-14T20:38:40Z', 33, 22, 3, 32, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:45:00Z', '2026-10-14T20:43:49Z', 34, 23, 3, 31, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:50:00Z', '2026-10-14T20:48:43Z', 35, 24, 3, 30, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T20:55:00Z', '2026-10-14T20:53:42Z', 34, 23, 4, 30, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:00:00Z', '2026-10-14T20:58:47Z', 34, 21, 4, 28, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:05:00Z', '2026-10-14T21:03:48Z', 37, 22, 4, 27, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:10:00Z', '2026-10-14T21:08:42Z', 39, 24, 4, 26, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:15:00Z', '2026-10-14T21:13:44Z', 37, 22, 4, 26, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:20:00Z', '2026-10-14T21:18:11Z', 41, 27, 4, 22, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:25:00Z', '2026-10-14T21:23:32Z', 45, 33, 4, 18, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:30:00Z', '2026-10-14T21:28:16Z', 55, 39, 4, 6, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:35:00Z', '2026-10-14T21:33:45Z', 63, 42, 4, 1, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:40:00Z', '2026-10-14T21:37:42Z', 63, 41, 4, 1, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:45:00Z', '2026-10-14T21:43:46Z', 62, 39, 5, 2, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:50:00Z', '2026-10-14T21:48:18Z', 62, 40, 4, 1, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T21:55:00Z', '2026-10-14T21:53:24Z', 64, 41, 4, 1, 0, TRUE, TRUE, TRUE),
    ('2241933651126795842', '2026-10-14T22:00:00Z', '2026-10-14T21:58:04Z', 63, 40, 4, 0, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:05:00Z', '2026-10-14T20:03:01Z', 77, 51, 0, 3, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:10:00Z', '2026-10-14T20:07:35Z', 77, 51, 0, 3, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:15:00Z', '2026-10-14T20:13:47Z', 75, 48, 0, 5, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:20:00Z', '2026-10-14T20:18:05Z', 75, 48, 0, 5, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:25:00Z', '2026-10-14T20:23:14Z', 76, 48, 0, 4, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:30:00Z', '2026-10-14T20:28:26Z', 75, 47, 1, 5, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:35:00Z', '2026-10-14T20:33:21Z', 75, 47, 0, 5, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:40:00Z', '2026-10-14T20:37:24Z', 73, 46, 0, 7, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:45:00Z', '2026-10-14T20:43:29Z', 69, 43, 0, 11, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:50:00Z', '2026-10-14T20:48:40Z', 68, 42, 0, 12, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:55:00Z', '2026-10-14T20:53:37Z', 66, 39, 0, 15, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:00:00Z', '2026-10-14T20:58:42Z', 64, 38, 1, 16, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:05:00Z', '2026-10-14T21:03:48Z', 61, 35, 2, 20, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:10:00Z', '2026-10-14T21:08:48Z', 44, 20, 2, 39, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:15:00Z', '2026-10-14T21:13:40Z', 30, 9, 1, 51, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:20:00Z', '2026-10-14T21:17:54Z', 22, 7, 0, 58, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:25:00Z', '2026-10-14T21:23:21Z', 18, 7, 0, 63, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:30:00Z', '2026-10-14T21:28:21Z', 15, 8, 1, 66, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:35:00Z', '2026-10-14T21:33:45Z', 7, 2, 0, 73, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:40:00Z', '2026-10-14T21:38:48Z', 0, 0, 0, 77, 1, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:45:00Z', '2026-10-14T21:42:33Z', 0, 0, 0, 80, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:50:00Z', '2026-10-14T21:48:46Z', 1, 0, 0, 79, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:55:00Z', '2026-10-14T21:52:41Z', 0, 0, 0, 80, 0, TRUE, TRUE, TRUE),
    ('66dc8382-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T22:00:00Z', '2026-10-14T21:58:36Z', 1, 1, 0, 78, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:05:00Z', '2026-10-14T20:03:14Z', 66, 62, 0, 15, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:10:00Z', '2026-10-14T20:08:30Z', 65, 61, 0, 16, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:15:00Z', '2026-10-14T20:13:38Z', 62, 59, 0, 19, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:20:00Z', '2026-10-14T20:18:38Z', 61, 57, 0, 20, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:25:00Z', '2026-10-14T20:23:31Z', 57, 54, 0, 24, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:30:00Z', '2026-10-14T20:28:45Z', 56, 53, 1, 25, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:35:00Z', '2026-10-14T20:33:39Z', 53, 51, 1, 28, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:40:00Z', '2026-10-14T20:38:43Z', 50, 48, 1, 31, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:45:00Z', '2026-10-14T20:43:47Z', 49, 47, 1, 32, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:50:00Z', '2026-10-14T20:48:49Z', 44, 41, 2, 35, 1, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T20:55:00Z', '2026-10-14T20:53:15Z', 40, 39, 1, 41, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:00:00Z', '2026-10-14T20:58:16Z', 38, 37, 2, 44, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:05:00Z', '2026-10-14T21:03:46Z', 32, 31, 2, 52, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:10:00Z', '2026-10-14T21:08:48Z', 23, 21, 0, 59, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:15:00Z', '2026-10-14T21:13:47Z', 17, 16, 0, 65, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:20:00Z', '2026-10-14T21:18:29Z', 12, 11, 0, 69, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:25:00Z', '2026-10-14T21:23:42Z', 4, 4, 0, 78, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:30:00Z', '2026-10-14T21:28:44Z', 0, 0, 0, 81, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:35:00Z', '2026-10-14T21:33:33Z', 0, 0, 0, 81, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:40:00Z', '2026-10-14T21:38:34Z', 1, 1, 0, 80, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:45:00Z', '2026-10-14T21:43:40Z', 2, 1, 0, 79, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:50:00Z', '2026-10-14T21:47:43Z', 0, 0, 0, 81, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T21:55:00Z', '2026-10-14T21:52:36Z', 1, 1, 0, 80, 0, TRUE, TRUE, TRUE),
    ('66dc7b10-0aca-11e7-82f6-3863bb44ef7c', '2026-10-14T22:00:00Z', '2026-10-14T21:58:45Z', 0, 0, 0, 81, 0, TRUE, TRUE, TRUE);
