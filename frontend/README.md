# Tandem Frontend

Next.js (App Router) + TypeScript + Tailwind CSS client for Tandem.

## Commands

Run these from `frontend/` (the root `Makefile` wraps them):

```bash
pnpm install     # install dependencies
pnpm dev         # dev server on :3000
pnpm build       # production build
pnpm start       # serve the production build
pnpm lint        # ESLint
pnpm typecheck   # next typegen + tsc --noEmit
```

`pnpm typecheck` runs `next typegen` first because Next.js generates the
route-aware global types (`PageProps`, `LayoutProps`, `RouteContext`) into
`.next/types`; `tsc` fails on a clean checkout without it.

## Layout

| Path | Purpose |
| --- | --- |
| `src/app/` | App Router routes, layouts, global styles |
| `src/lib/env.ts` | Client-visible environment configuration |
| `src/lib/api.ts` | Typed backend client (currently just `/health`) |

## Configuration

The only variable today is `NEXT_PUBLIC_API_BASE_URL` (default
`http://localhost:8000`). Put local overrides in `frontend/.env.local`, which is
gitignored. Only `NEXT_PUBLIC_*` variables reach the browser — never put a
secret behind that prefix.

## Conventions

- Timestamps cross the wire as UTC ISO 8601 strings. Convert to
  America/New_York at render time only; never store local time.
- `AGENTS.md` / `CLAUDE.md` are generated and re-added by `next dev`; they are
  committed so the working tree stays clean.
