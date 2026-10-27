import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Regression: `start:worker:dev` ran the worker under tsx, whose esbuild
 * transform emits no decorator metadata, so Nest DI failed on startup
 * (EmailPasswordAuthService index [1]). The dev worker must compile with tsc.
 */
describe('start:worker:dev script', () => {
  const root = join(__dirname, '..', '..');
  const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')) as {
    scripts: Record<string, string>;
  };

  it('does not run the Nest worker through tsx', () => {
    const script = pkg.scripts['start:worker:dev'];
    expect(script).toBeDefined();
    expect(script).not.toMatch(/\btsx\b/);
    expect(script).toContain('--entryFile workers/worker-main');
  });

  it('builds into its own outDir so it never wipes the API dist', () => {
    const script = pkg.scripts['start:worker:dev'];
    const path = /--path\s+(\S+)/.exec(script)?.[1];
    expect(path).toBeDefined();
    const cfg = JSON.parse(readFileSync(join(root, path!), 'utf8')) as {
      compilerOptions: { outDir: string };
    };
    expect(cfg.compilerOptions.outDir).not.toMatch(/^\.?\/?dist\/?$/);
  });
});
