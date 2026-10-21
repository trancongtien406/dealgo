import { defineConfig } from 'vitest/config';

/**
 * Two projects: fast in-memory specs keep the 5 s default; the Postgres concurrency suite
 * (test/concurrency, skipped without DATABASE_URL) gets 20 s per test and 60 s per hook so a
 * loaded machine (simulator, Docker) does not turn slow transactions into false failures.
 */
export default defineConfig({
  // Resolves the path aliases declared in tsconfig.json, including the ones
  // added by `nest g library`. Requires Vite 8, which ships this option.
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          include: ['**/*.spec.ts'],
          exclude: ['**/node_modules/**', 'dist/**', 'test/concurrency/**'],
        },
      },
      {
        extends: true,
        test: {
          name: 'postgres',
          include: ['test/concurrency/**/*.spec.ts'],
          testTimeout: 20_000,
          hookTimeout: 60_000,
        },
      },
    ],
  },
});
