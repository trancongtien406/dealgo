import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();
const fetchOpsUpstreamBinary = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
  fetchOpsUpstreamBinary: (...args: unknown[]) => fetchOpsUpstreamBinary(...args),
}));

const { POST } = await import("./route");
const { GET } = await import("../documents/[index]/route");

const ID = "6f1c2b8e-3a1d-4c2e-9f7a-1b2c3d4e5f60";
const ctx = { params: Promise.resolve({ id: ID }) };

function reject(body: unknown): Request {
  return new Request(`http://localhost:3000/api/ops/partner-applications/${ID}/reject`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: "http://localhost:3000" },
    body: JSON.stringify(body),
  });
}

describe("partner application reject BFF", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
    fetchOpsUpstream.mockResolvedValue({ ok: true, status: 200, data: {} });
    fetchOpsUpstreamBinary.mockReset();
  });

  it("forwards trimmed issues with the reason", async () => {
    const res = await POST(
      reject({ reason: "Bổ sung", issues: [{ section: "SELFIE", note: " Ảnh mờ " }] }),
      ctx,
    );
    expect(res.status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenCalledWith(
      expect.objectContaining({
        body: { reason: "Bổ sung", issues: [{ section: "SELFIE", note: "Ảnh mờ" }] },
      }),
    );
  });

  it("refuses malformed issues before calling Nest", async () => {
    for (const issues of [
      [{ section: "SELFIE", note: "" }],
      [{ section: "bad section", note: "x" }],
      "SELFIE",
      Array.from({ length: 11 }, () => ({ section: "OTHER", note: "x" })),
    ]) {
      const res = await POST(reject({ reason: "x", issues }), ctx);
      expect(res.status).toBe(400);
    }
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
  });

  it("streams documents with safe headers and validates the index", async () => {
    fetchOpsUpstreamBinary.mockResolvedValue({
      ok: true,
      body: new Uint8Array([0xff, 0xd8, 0xff]).buffer,
      contentType: "image/jpeg",
      disposition: 'inline; filename="ID_FRONT-0.jpg"',
    });
    const bad = await GET(new Request("http://localhost/x"), {
      params: Promise.resolve({ id: ID, index: "abc" }),
    });
    expect(bad.status).toBe(400);
    const res = await GET(new Request("http://localhost/x"), {
      params: Promise.resolve({ id: ID, index: "0" }),
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("image/jpeg");
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
    expect(res.headers.get("cache-control")).toContain("no-store");
    expect(fetchOpsUpstreamBinary).toHaveBeenCalledWith(
      `/v1/ops/partner-applications/${ID}/documents/0`,
    );
  });
});
