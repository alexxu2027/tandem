import { env } from "@/lib/env";

/** Payload returned by the backend's `GET /health` endpoint. */
export type Health = {
  status: "ok";
  service: string;
  version: string;
  environment: string;
  /** ISO 8601, always UTC. */
  timestamp: string;
};

/**
 * Fetch the backend health check.
 *
 * Returns `null` instead of throwing when the backend is unreachable, so the
 * UI can render a "not running" state during local development.
 */
export async function fetchHealth(): Promise<Health | null> {
  try {
    const baseUrl =
      typeof window === "undefined" ? env.serverApiBaseUrl : env.apiBaseUrl;
    const response = await fetch(`${baseUrl}/health`, {
      cache: "no-store",
    });
    if (!response.ok) return null;
    return (await response.json()) as Health;
  } catch {
    return null;
  }
}
