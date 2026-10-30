import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const jar = new Map<string, string>();
vi.mock("next/headers", () => ({
  cookies: async () => ({
    get: (n: string) => (jar.has(n) ? { value: jar.get(n) } : undefined),
    set: (n: string, v: string) => jar.set(n, v),
  }),
}));
vi.mock("@/lib/api/nest-base-url", () => ({ nestApiBaseUrl: () => "http://nest.test" }));

const { openOpsUpstreamStream } = await import("./ops-upstream");
const { OPS_ACCESS_COOKIE } = await import("@/lib/ops-cookies");

const sse = () =>
  new Response("event: ready\ndata: {}\n\n", { headers: { "content-type": "text/event-stream" } });

describe("openOpsUpstreamStream", () => {
  const fetchMock = vi.fn();
  beforeEach(() => {
    jar.clear();
    fetchMock.mockReset();
    vi.stubGlobal("fetch", fetchMock);
  });
  afterEach(() => vi.unstubAllGlobals());

  it("sends the cookie bearer with Accept: text/event-stream and the caller's signal (no timeout)", async () => {
    jar.set(OPS_ACCESS_COOKIE, "acc");
    fetchMock.mockResolvedValue(sse());
    const ac = new AbortController();
    const r = await openOpsUpstreamStream("/v1/ops/events", ac.signal);
    expect(r.ok).toBe(true);
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(String(url)).toBe("http://nest.test/v1/ops/events");
    expect(init.headers).toMatchObject({ Accept: "text/event-stream", Authorization: "Bearer acc" });
    expect(init.signal).toBe(ac.signal);
  });

  it("returns 401 without a session and never calls Nest", async () => {
    const r = await openOpsUpstreamStream("/v1/ops/events", new AbortController().signal);
    expect(r).toMatchObject({ ok: false, status: 401 });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects a non-SSE upstream", async () => {
    jar.set(OPS_ACCESS_COOKIE, "acc");
    fetchMock.mockResolvedValue(new Response("{}", { headers: { "content-type": "application/json" } }));
    const r = await openOpsUpstreamStream("/v1/ops/events", new AbortController().signal);
    expect(r).toMatchObject({ ok: false, status: 502 });
  });
});
