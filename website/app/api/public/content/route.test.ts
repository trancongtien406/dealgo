import { afterEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

const req = (q: string) => new Request(`http://localhost:3000/api/public/content?${q}`);

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("GET /api/public/content", () => {
  it("returns the published CMS page from the API", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        success: true,
        data: {
          slug: "terms",
          locale: "en",
          title: "Terms of Use",
          summary: null,
          content: { badge: "", sections: [{ id: "a", title: "1", content: "x" }] },
          version: 3,
          effectiveAt: "2026-11-01T00:00:00.000Z",
          publishedAt: "2026-10-26T03:00:00.000Z",
          source: "cms",
        },
      }),
    );
    vi.stubGlobal("fetch", fetchMock);
    const res = await GET(req("key=TERMS&lang=en"));
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.version).toBe(3);
    expect(String(fetchMock.mock.calls[0]?.[0 as never])).toContain("/v1/public/pages/terms?locale=en");
  });

  it("falls back offline without fake contact data", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("down"); }));
    const json = await (await GET(req("key=support"))).json();
    expect(json.data.content.hotline).toBe("");
    expect(json.data.source).toBe("default");
    const legal = await (await GET(req("key=privacy"))).json();
    expect(legal.data.content.sections.length).toBe(1);
  });

  it("returns 404 for unknown keys", async () => {
    const res = await GET(req("key=UNKNOWN"));
    expect(res.status).toBe(404);
  });
});
