# Local Development

## Prerequisites

| Tool | Version | Install |
| --- | --- | --- |
| [uv](https://docs.astral.sh/uv/) | ≥ 0.5 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (or `winget install astral-sh.uv`) |
| [pnpm](https://pnpm.io/) | ≥ 9 | `npm install -g pnpm` — see the corepack note below |
| [Docker](https://docs.docker.com/get-docker/) | with Compose v2 | Docker Desktop |
| Node.js | ≥ 20 | [nodejs.org](https://nodejs.org) |
| GNU Make | any | Preinstalled on macOS/Linux; see the Windows note below |

Python itself is not a prerequisite — `uv` downloads and pins the interpreter.

> **corepack on Windows:** `corepack enable pnpm` is the usual way to get pnpm,
> but it writes a shim next to the Node binary and fails with
> `EPERM: operation not permitted, open 'C:\Program Files\nodejs\pnpm'` unless
> the terminal is elevated. `npm install -g pnpm` installs into
> `%APPDATA%\npm` instead and works from a normal shell.

> **Not yet executed:** Docker and GNU Make were not installed on the machine
> this repository was scaffolded on, so the Compose stack, the Dockerfiles and
> the `make` targets have been reviewed and syntax-checked but never run. The
> plain commands listed throughout this document have all been run and pass.

## First run

```bash
git clone <repo-url> tandem
cd tandem

make setup        # creates .env, installs backend + frontend dependencies
make up           # starts PostgreSQL + PostGIS
make migrate      # applies migrations (a no-op until the first model lands)
```

Then, in two terminals:

```bash
make backend      # http://localhost:8000
make frontend     # http://localhost:3000
```

Verify:

```bash
curl localhost:8000/health      # process liveness
curl localhost:8000/health/db   # database + PostGIS reachability
open http://localhost:8000/docs # interactive API docs
```

## Everyday commands

```bash
make help         # list every target
make test         # backend test suite
make lint         # Ruff + ESLint + tsc
make format       # auto-fix both sides
make psql         # psql shell in the database container
make logs         # tail container logs
make down         # stop containers, keep data
make clean        # remove build artifacts and caches
```

## Running everything in Docker

The `app` profile builds and runs the backend and frontend as containers too:

```bash
docker compose --profile app up --build
```

Useful for checking the images build; the bare-metal workflow above has faster
reloads for day-to-day work.

## Windows

The Makefile needs a POSIX shell. Three options:

1. **WSL2** (recommended) — clone inside the WSL filesystem, not `/mnt/c`;
   file watching and I/O are dramatically faster there.
2. **Git Bash + GNU Make** — `winget install GnuWin32.Make` and make sure
   `make` is on `PATH`.
3. **Skip make** — run the underlying commands directly. Every target is a
   one-liner; `make help` lists them, and the root README spells out the main
   ones.

Docker Desktop must be running before `make up` either way.

## Troubleshooting

**`make: command not found`** — see the Windows section above.

**Backend cannot reach the database** — check Postgres is healthy
(`make ps`) and that `POSTGRES_HOST` is `localhost` when running the backend on
your machine, or `db` when running it inside Compose.

**Frontend shows "Backend unreachable"** — the API is not running, or
`NEXT_PUBLIC_API_BASE_URL` points somewhere else. `NEXT_PUBLIC_*` values are
baked in at build time; restart the dev server after changing one.

**`tsc` fails with "Cannot find name 'PageProps'/'LayoutProps'"** — Next.js
generates those global types into `.next/types`. Run `pnpm typecheck`, which
runs `next typegen` first, rather than bare `tsc --noEmit`.

**Port already in use** — change `BACKEND_PORT` or `POSTGRES_PORT` in `.env`.
The frontend port is set with `pnpm dev --port 3001`.

**Stale Python environment** — `rm -rf backend/.venv && make setup-backend`.

**Stale frontend build** — `make clean && make setup-frontend`.

For database-specific problems see [database.md](database.md).
