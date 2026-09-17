# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Tandem frontend image.
#
#   dev  - source is bind-mounted by Compose, `next dev` with hot reload
#   prod - standalone Next.js server (requires output: "standalone" in
#          next.config.ts, which is enabled when NEXT_OUTPUT=standalone)
# ---------------------------------------------------------------------------

FROM node:22-alpine AS base

ENV PNPM_HOME="/pnpm" \
    PATH="/pnpm:$PATH" \
    TZ=UTC
RUN corepack enable

WORKDIR /app

# ---------------------------------------------------------------------------
# Dependency layer - cached unless the lockfile changes.
# ---------------------------------------------------------------------------
FROM base AS deps

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# ---------------------------------------------------------------------------
# Development target.
# ---------------------------------------------------------------------------
FROM deps AS dev

COPY . .
EXPOSE 3000
CMD ["pnpm", "dev"]

# ---------------------------------------------------------------------------
# Build the production bundle.
# ---------------------------------------------------------------------------
FROM deps AS builder

COPY . .
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_OUTPUT=standalone
RUN pnpm build

# ---------------------------------------------------------------------------
# Production target - minimal runtime.
# ---------------------------------------------------------------------------
FROM base AS prod

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000

RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
