import { fetchHealth } from "@/lib/api";
import { env } from "@/lib/env";

export const dynamic = "force-dynamic";

export default async function Home() {
  const health = await fetchHealth();

  return (
    <div className="flex flex-1 flex-col items-center justify-center bg-zinc-50 px-6 font-sans dark:bg-black">
      <main className="w-full max-w-xl space-y-8">
        <header className="space-y-2">
          <h1 className="text-4xl font-semibold tracking-tight">Tandem</h1>
          <p className="text-zinc-600 dark:text-zinc-400">
            Predictive Citi Bike navigation for New York City. This is the
            scaffold — no product features are implemented yet.
          </p>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white p-5 dark:border-zinc-800 dark:bg-zinc-950">
          <h2 className="mb-3 text-sm font-medium uppercase tracking-wide text-zinc-500">
            Backend
          </h2>
          {health ? (
            <dl className="space-y-1 font-mono text-sm">
              <div className="flex justify-between gap-4">
                <dt className="text-zinc-500">status</dt>
                <dd className="text-emerald-600 dark:text-emerald-400">
                  {health.status}
                </dd>
              </div>
              <div className="flex justify-between gap-4">
                <dt className="text-zinc-500">version</dt>
                <dd>{health.version}</dd>
              </div>
              <div className="flex justify-between gap-4">
                <dt className="text-zinc-500">environment</dt>
                <dd>{health.environment}</dd>
              </div>
              <div className="flex justify-between gap-4">
                <dt className="text-zinc-500">server time (UTC)</dt>
                <dd>{health.timestamp}</dd>
              </div>
            </dl>
          ) : (
            <p className="text-sm text-amber-600 dark:text-amber-400">
              Backend unreachable at{" "}
              <code className="font-mono">{env.apiBaseUrl}</code>. Start it with{" "}
              <code className="font-mono">make backend</code>.
            </p>
          )}
        </section>
      </main>
    </div>
  );
}
