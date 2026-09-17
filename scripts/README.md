# Scripts

Operational helper scripts.

| Script | Purpose |
| --- | --- |
| `init_postgis.sql` | Enables PostGIS, `postgis_topology` and `pg_trgm`, and pins the database to UTC. Run automatically by Docker Compose the first time the Postgres volume is created, and by CI before migrations. |

Scripts that need application code should be run through `uv` from `backend/`
so they get the project environment:

```bash
cd backend && uv run python ../scripts/your_script.py
```
