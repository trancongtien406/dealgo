import { readdirSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Applied migrations are never renamed: Prisma stores the folder name in `_prisma_migrations`,
 * so a rename makes `migrate deploy` treat the folder as a new migration and re-run it.
 *
 * Two historical quirks are therefore frozen here instead of fixed:
 * - three folders share the timestamp 20261014160000 (Prisma orders them by full name, which
 *   is the order they were applied in);
 * - six folders carry a release tag (`r18_`, `r19_`, `r20_`) in their name.
 *
 * New migrations must use a unique timestamp and a descriptive name without a release tag.
 */
const MIGRATIONS_DIR = join(__dirname, '..', '..', 'prisma', 'migrations');

const KNOWN_SHARED_TIMESTAMPS = new Set(['20261014160000', '20261107090000']);

const KNOWN_TAGGED = new Set([
  '20261105090000_r18_dispatch_lifecycle',
  '20261105091000_r18_dispatch_settings',
  '20261106090000_r19_logic_gaps',
  '20261106091000_r19_settings',
  '20261106092000_r19_ops_audit_enums',
  '20261107090000_r20_commissions',
]);

const RELEASE_TAG = /_(r\d+|round\d*|vong\d*)(_|$)/i;

function migrationFolders(): string[] {
  return readdirSync(MIGRATIONS_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

describe('prisma migration folder names', () => {
  it('start with a 14-digit timestamp and a snake_case name', () => {
    for (const name of migrationFolders()) {
      expect(name).toMatch(/^\d{14}_[a-z0-9_]+$/);
    }
  });

  it('use a unique timestamp (except the frozen historical one)', () => {
    const seen = new Map<string, number>();
    for (const name of migrationFolders()) {
      const stamp = name.slice(0, 14);
      seen.set(stamp, (seen.get(stamp) ?? 0) + 1);
    }
    const duplicated = [...seen.entries()]
      .filter(([stamp, count]) => count > 1 && !KNOWN_SHARED_TIMESTAMPS.has(stamp))
      .map(([stamp]) => stamp);
    expect(duplicated).toEqual([]);
  });

  it('carry no release tag (except the frozen historical ones)', () => {
    const tagged = migrationFolders().filter(
      (name) => RELEASE_TAG.test(name) && !KNOWN_TAGGED.has(name),
    );
    expect(tagged).toEqual([]);
  });

  it('keeps the frozen lists accurate', () => {
    const names = new Set(migrationFolders());
    for (const name of KNOWN_TAGGED) expect(names.has(name)).toBe(true);
  });
});
