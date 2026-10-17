import { describe, expect, it } from "vitest";
import { GET } from "./route";

describe("Public Content Route GET /api/public/content", () => {
  it("returns 200 and TERMS document when key=TERMS", async () => {
    const req = new Request(
      "http://localhost:3000/api/public/content?key=TERMS",
    );
    const res = await GET(req);
    expect(res.status).toBe(200);

    const json = await res.json();
    expect(json.success).toBe(true);
    expect(json.data.key).toBe("TERMS");
    expect(json.data.title).toContain("Điều khoản & Điều kiện");
  });

  it("returns 200 and PRIVACY document when key=PRIVACY", async () => {
    const req = new Request(
      "http://localhost:3000/api/public/content?key=privacy",
    );
    const res = await GET(req);
    expect(res.status).toBe(200);

    const json = await res.json();
    expect(json.success).toBe(true);
    expect(json.data.key).toBe("PRIVACY");
    expect(json.data.title).toContain("Quyền riêng tư & Bảo mật");
  });

  it("returns 200 and SUPPORT config when key=SUPPORT", async () => {
    const req = new Request(
      "http://localhost:3000/api/public/content?key=SUPPORT",
    );
    const res = await GET(req);
    expect(res.status).toBe(200);

    const json = await res.json();
    expect(json.success).toBe(true);
    expect(json.data.hotline).toBe("1900 6868");
    expect(json.data.categories.length).toBeGreaterThan(0);
  });

  it("returns live CMS document from backend when available", async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () =>
      new Response(
        JSON.stringify({
          success: true,
          data: {
            items: [
              {
                id: "cms-live-terms",
                kind: "POLICY",
                title: "Điều khoản DealGo Live",
                body: JSON.stringify({
                  key: "TERMS",
                  title: "Điều khoản DealGo Cập nhật Trực tiếp",
                  badge: "Chính sách DealGo Live",
                  version: "v3.0",
                  effectiveDate: "2026-10-17",
                  summary: "Phiên bản live",
                  sections: [],
                  updatedAt: "2026-10-17T08:00:00Z",
                  updatedBy: "Admin Trực ban",
                }),
                status: "PUBLISHED",
                createdAt: "2026-10-17T08:00:00Z",
              },
            ],
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );

    try {
      const req = new Request(
        "http://localhost:3000/api/public/content?key=TERMS",
      );
      const res = await GET(req);
      expect(res.status).toBe(200);

      const json = await res.json();
      expect(json.success).toBe(true);
      expect(json.data.title).toBe("Điều khoản DealGo Cập nhật Trực tiếp");
      expect(json.data.version).toBe("v3.0");
      expect(json.data.updatedBy).toBe("Admin Trực ban");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("returns 404 when key is invalid or missing", async () => {
    const req = new Request(
      "http://localhost:3000/api/public/content?key=UNKNOWN",
    );
    const res = await GET(req);
    expect(res.status).toBe(404);

    const json = await res.json();
    expect(json.success).toBe(false);
  });
});
