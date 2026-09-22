/**
 * Environment configuration.
 *
 * Only `NEXT_PUBLIC_*` variables are readable in the browser. Server-only
 * secrets must never be added here.
 */

const PUBLIC_API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export const env = {
  /** Base URL the browser uses to reach the backend, e.g. http://localhost:8000 */
  apiBaseUrl: PUBLIC_API_BASE_URL,
  /**
   * Base URL for fetches made on the server. In Compose the frontend and the
   * backend are separate containers, so `localhost` points at the frontend
   * itself; `API_BASE_URL_INTERNAL` names the backend on the Compose network.
   * Outside Compose it is unset and this is the public URL.
   *
   * Server-only: not `NEXT_PUBLIC_*`, so it is never inlined into the browser
   * bundle, and `fetchHealth` only reads it when `window` is undefined.
   */
  serverApiBaseUrl: process.env.API_BASE_URL_INTERNAL ?? PUBLIC_API_BASE_URL,
} as const;
