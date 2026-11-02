import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * ADM-001: every cookie-authenticated ops mutation must reject cross-site requests.
 * A route passes when it calls assertSameOriginMutation itself or forwards through
 * forwardOpsJsonMutation (which calls it). session/refresh has its own Sec-Fetch-Site check.
 */
const ROOT = join(process.cwd(), "app/api/ops");
const OWN_CHECK = new Set(["session/refresh/route.ts"]);
const MUTATION = /export\s+(?:async\s+function|const)\s+(POST|PUT|PATCH|DELETE)\b/;

function routes(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return routes(path);
    return name === "route.ts" ? [path] : [];
  });
}

describe("ops BFF mutations are same-origin guarded (ADM-001)", () => {
  const files = routes(ROOT);

  it("finds the ops routes", () => {
    expect(files.length).toBeGreaterThan(20);
  });

  it("guards every POST/PUT/PATCH/DELETE handler", () => {
    const unguarded = files
      .filter((file) => MUTATION.test(readFileSync(file, "utf8")))
      .map((file) => relative(ROOT, file).replaceAll("\\", "/"))
      .filter((rel) => !OWN_CHECK.has(rel))
      .filter((rel) => {
        const src = readFileSync(join(ROOT, rel), "utf8");
        return !src.includes("assertSameOriginMutation(") && !src.includes("forwardOpsJsonMutation(");
      });
    expect(unguarded).toEqual([]);
  });
});
