import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The production Docker target builds with NEXT_OUTPUT=standalone so the
  // image can ship a self-contained server.js without node_modules.
  output: process.env.NEXT_OUTPUT === "standalone" ? "standalone" : undefined,

  // Surfaces accidental double-render bugs during development.
  reactStrictMode: true,
};

export default nextConfig;
