import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
    // t61u: bypass now defaults off (DEC-PROD-070); e2e flows opt in like test/support/app-harness.
    env: { PARTNER_ELIGIBILITY_BYPASS: 'true' },
  },
});
