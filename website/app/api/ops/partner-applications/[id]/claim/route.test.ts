import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();
vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { POST } = await import("./route");
const ID = "6f1c2b8e-3a1d-4c2e-9f7a-1b2c3d4e5f60";

function claim(id: string, origin = "http://localhost:3000"): [Request, { params: Promise<{ id: string }> }] {
  return [
    new Request(`http://localhost:3000/api/ops/partner-applications/${id}/claim`, {
      method: "POST",
      headers: { Origin: origin },
    }),
    { params: Promise.resolve({ id }) },
  ];
}

describe("partner application claim BFF (t52u)", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
    fetchOpsUpstream.mockResolvedValue({ ok: true, status: 200, data: { success: true, data: {} } });
  });

  it("forwards to the Nest claim endpoint", async () => {
    const res = await POST(...claim(ID));
    expect(res.status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenCalledWith({
      method: "POST",
      path: `/v1/ops/partner-applications/${ID}/claim`,
      body: {},
    });
  });

  it("rejects bad ids and cross-origin posts before calling Nest", async () => {
    expect((await POST(...claim("not-a-uuid"))).status).toBe(400);
    expect((await POST(...claim(ID, "https://evil.example"))).status).toBe(403);
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
  });
});
