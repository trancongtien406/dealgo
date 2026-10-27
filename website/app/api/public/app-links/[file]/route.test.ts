import { afterEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

const call = (file: string) =>
  GET(new Request(`http://localhost:3000/.well-known/${file}`), {
    params: Promise.resolve({ file }),
  });

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("GET /.well-known/* (app links)", () => {
  it("proxies the association file from the API", async () => {
    const fetchMock = vi.fn<(url: string) => Promise<Response>>(async () => Response.json({ webcredentials: { apps: ["T.app"] } }));
    vi.stubGlobal("fetch", fetchMock);
    const res = await call("apple-app-site-association");
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("application/json");
    expect(await res.json()).toEqual({ webcredentials: { apps: ["T.app"] } });
    expect(String(fetchMock.mock.calls[0]?.[0])).toMatch(/\/\.well-known\/apple-app-site-association$/);
  });

  it("404s for unknown files and when the API has none", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response(null, { status: 404 })));
    expect((await call("secrets.json")).status).toBe(404);
    expect((await call("assetlinks.json")).status).toBe(404);
  });
});
