import { beforeEach, describe, expect, it, vi } from "vitest";

const openOpsUpstreamStream = vi.fn();
vi.mock("@/lib/api/ops-upstream", () => ({
  openOpsUpstreamStream: (...args: unknown[]) => openOpsUpstreamStream(...args),
}));

const { GET } = await import("./route");

describe("GET /api/ops/events (SSE BFF)", () => {
  beforeEach(() => openOpsUpstreamStream.mockReset());

  it("pipes the upstream stream with SSE headers and forwards the abort signal", async () => {
    const body = new ReadableStream({
      start(c) {
        c.enqueue(new TextEncoder().encode("event: monitor\ndata: {}\n\n"));
        c.close();
      },
    });
    openOpsUpstreamStream.mockResolvedValue({ ok: true, upstream: new Response(body) });
    const ac = new AbortController();
    const res = await GET(new Request("http://localhost:3000/api/ops/events", { signal: ac.signal }));
    expect(openOpsUpstreamStream).toHaveBeenCalledWith("/v1/ops/events", expect.any(AbortSignal));
    expect(res.headers.get("content-type")).toContain("text/event-stream");
    expect(res.headers.get("cache-control")).toContain("no-transform");
    expect(await res.text()).toContain("event: monitor");
  });

  it("maps auth failures to JSON so EventSource stops and the client backs off", async () => {
    openOpsUpstreamStream.mockResolvedValue({ ok: false, status: 401, message: "Chưa đăng nhập." });
    const res = await GET(new Request("http://localhost:3000/api/ops/events"));
    expect(res.status).toBe(401);
    expect(await res.json()).toMatchObject({ success: false });
  });
});
