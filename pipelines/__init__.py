"""Data ingestion pipelines.

Each subpackage owns one external source. Nothing is implemented yet; these are
placeholders so the module boundaries are fixed before the code arrives.

Every pipeline follows the same contract:

1. Fetch from the source, writing the untouched payload to ``data/raw/``.
2. Normalise into the Tandem schema, writing to ``data/processed/``.
3. Load into PostgreSQL.

All timestamps are converted to UTC at ingestion time. A source that reports
local New York time is converted immediately; the local value is never stored.
"""
