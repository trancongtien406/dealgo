import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

// C: the Mapbox token comes from env only (MAPBOX_ACCESS_TOKEN /
// mobile --dart-define MAPS_API_KEY). Fail if a literal token lands in source.
const TOKEN = /\b[ps]k\.eyJ[A-Za-z0-9_-]{10,}/;

function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name.startsWith('.') || name === 'build') continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(ts|js|dart|json|plist|xml|gradle|kt|swift)$/.test(name)) out.push(p);
  }
  return out;
}

describe('no hardcoded Mapbox token', () => {
  it('backend/src and mobile/lib, ios, android contain no pk./sk. literal', () => {
    const roots = ['src', '../mobile/lib', '../mobile/ios/Runner', '../mobile/android/app/src'];
    const offenders = roots
      .flatMap((r) => {
        try {
          return walk(r);
        } catch {
          return [];
        }
      })
      .filter((f) => TOKEN.test(readFileSync(f, 'utf8')));
    expect(offenders).toEqual([]);
  });
});
