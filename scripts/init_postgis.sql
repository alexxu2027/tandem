-- Runs once, when the Postgres data volume is first initialized.
--
-- The postgis/postgis image already installs the extension binaries; this
-- enables them inside the Tandem database. Keep extension management here
-- rather than in an Alembic migration so that migrations stay portable and do
-- not need superuser privileges.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Trigram indexes for fuzzy station-name lookup later on.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tandem stores every timestamp in UTC. Dynamic SQL because the database name
-- is only known at runtime.
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'UTC');
END
$$;
