import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    fileParallelism: false,
    include: ["tests/local-d1/**/*.test.ts"],
    testTimeout: 120_000,
  },
});
