/**
 * Client-visible environment configuration.
 *
 * Only `NEXT_PUBLIC_*` variables are readable in the browser. Server-only
 * secrets must never be added here.
 */
export const env = {
  /** Base URL of the Tandem backend, e.g. http://localhost:8000 */
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000",
} as const;
