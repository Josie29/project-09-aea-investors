import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  // Resolves the `@/*` alias straight from tsconfig.json, so imports look the
  // same in tests as they do in application code.
  resolve: { tsconfigPaths: true },
  test: {
    environment: "jsdom",
    // Project convention: tests live in src/__tests__/, never beside source.
    include: ["src/__tests__/**/*.test.{ts,tsx}"],
    setupFiles: ["./vitest.setup.ts"],
    css: true,
  },
});
