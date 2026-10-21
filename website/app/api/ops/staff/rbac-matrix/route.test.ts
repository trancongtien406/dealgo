import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { GET } = await import("./route");

describe("BFF GET /api/ops/staff/rbac-matrix (DEC-PROD-045)", () => {
  beforeEach(() => fetchOpsUpstream.mockReset());

  it("proxies the Nest matrix", async () => {
    const data = { roles: ["ADMIN"], permissions: ["customers.write"], grants: { ADMIN: ["customers.write"] } };
    fetchOpsUpstream.mockResolvedValue({ ok: true, status: 200, data });
    const res = await GET();
    expect(res.status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenCalledWith({ path: "/v1/ops/staff/rbac-matrix" });
    expect((await res.json()).data).toEqual(data);
  });

  it("passes upstream errors through", async () => {
    fetchOpsUpstream.mockResolvedValue({ ok: false, status: 403, error: { message: "denied" } });
    expect((await GET()).status).toBe(403);
  });
});
