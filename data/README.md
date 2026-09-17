# Data

Working directory for datasets. **Nothing in `raw/` or `processed/` is
committed** — both are gitignored, and the `.gitkeep` files exist only to keep
the directory structure in the repository.

| Path | Contents |
| --- | --- |
| `raw/` | Untouched payloads exactly as fetched from a source. Never edited by hand. |
| `processed/` | Normalised, analysis-ready outputs derived from `raw/`. Always reproducible by re-running a pipeline. |

Anything in here must be reproducible from a pipeline run. If a file cannot be
regenerated, it does not belong in this directory.

## Conventions

- Partition by source and UTC date: `data/raw/citibike/station_status/2026-09-17/`.
- Timestamps in filenames and inside files are UTC, ISO 8601.
- Large or licensed datasets stay local. If a dataset needs to be shared, put
  it in object storage and reference it from a pipeline config.
