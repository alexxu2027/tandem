# Architecture

> Status: scaffold. This describes the intended shape. Only the backend
> skeleton, the frontend shell and the database exist today.

## Overview

```
  External sources                  Tandem                        Client
  ----------------                  ------                        ------

  Citi Bike GBFS  ─┐
  Weather         ─┤                                         ┌──────────────┐
  NYC Open Data   ─┼─►  pipelines/  ──►  PostgreSQL   ◄──────►│   backend/   │◄──► frontend/
  Incidents       ─┘      (ingest)       + PostGIS            │   FastAPI    │      Next.js
                                              ▲               └──────────────┘
                                              │                      ▲
                                              └──────  ml/  ─────────┘
                                                    (train)      (serve predictions)
```

## Components

### `backend/` — FastAPI

The only component the frontend talks to. Layered as routes → services →
models, with Pydantic schemas defining the wire format separately from the ORM
models that define storage.

`app/routing/` and `app/prediction/` are deliberately separate packages: route
planning and availability prediction are the two pieces of real algorithmic
work, and isolating them keeps them testable without HTTP.

### Database — PostgreSQL + PostGIS

PostGIS rather than plain Postgres because nearly every query Tandem needs is
spatial: stations near a point, stations along a corridor, route segments
intersecting a closure. Doing that in application code means pulling the whole
station table into memory on every request.

Schema changes go through Alembic. Extensions are enabled in
`scripts/init_postgis.sql` at database initialization, not in a migration, so
migrations stay portable and need no superuser privileges.

### `pipelines/` — ingestion

One package per external source, each following the same fetch → normalise →
load contract. Raw payloads are archived to `data/raw/` before transformation
so a schema change can be replayed without re-fetching.

### `ml/` — prediction models

Training lives outside the backend so the API image stays free of ML
dependencies. The backend consumes trained artifacts through
`app/prediction/`.

### `frontend/` — Next.js

App Router with server components. Talks to the backend over HTTP using the
typed client in `src/lib/api.ts`. The only place in the system that converts
UTC to New York local time.

## Why "predictive"

A rider needs to know whether a bike will be there when they *arrive*, not
whether one is there now. On a 15-minute trip to a station during rush hour,
current availability is a poor predictor of availability on arrival. That gap
is the product: the routing layer asks the prediction layer for availability at
the estimated arrival time, and prefers routes that are likely to work rather
than routes that look good right now.

## Data flow at request time (intended)

1. Client asks for a route between two points.
2. Backend finds candidate start and end stations with a PostGIS proximity query.
3. For each candidate, the prediction layer estimates bike/dock availability at
   the estimated arrival time.
4. The routing layer scores candidate routes by travel time *and* the
   probability that the ride actually works end to end.
5. Backend returns ranked routes with their confidence.

## Key decisions

| Decision | Reason |
| --- | --- |
| Monorepo | Backend, frontend, pipelines and ML share schemas and conventions; one PR can change a model and its consumer together. |
| PostGIS over app-side geo | Spatial filtering belongs in an index, not in Python. |
| UTC everywhere | See [conventions.md](conventions.md); DST corrupts historical training data. |
| Raw data archived before transform | Lets a schema change be replayed without re-fetching from rate-limited sources. |
| ML separate from backend | Keeps the API image small and the training dependencies out of production. |
| `uv` + `pnpm` | Lockfile-based, reproducible, fast in CI. |
