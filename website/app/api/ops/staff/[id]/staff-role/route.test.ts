import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { POST } = await import("./route");

const STAFF = "44444444-4444-4444-8444-444444444444";

function post(body: unknown, id = STAFF) {
  const req = new Request(`http://localhost:3000/api/ops/staff/${id}/staff-role`, {
    method: "POST",
    headers: {
      Origin: "http://localhost:3000",
      Host: "localhost:3000",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  return POST(req, { params: Promise.resolve({ id }) });
}

describe("BFF POST /api/ops/staff/[id]/staff-role (DEC-PROD-043/044)", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
  });

  it("proxies a valid role change to Nest", async () => {
    fetchOpsUpstream.mockResolvedValue({
      ok: true,
      status: 200,
      data: { userId: STAFF, staffRole: "FINANCE" },
    });
    const res = await post({ staffRole: "finance", reason: "  đổi ca  " });
    expect(res.status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenCalledWith({
      method: "POST",
      path: `/v1/ops/staff/${STAFF}/staff-role`,
      body: { staffRole: "FINANCE", reason: "đổi ca" },
    });
  });

  it("rejects unknown roles, short reasons and bad ids without calling Nest", async () => {
    expect((await post({ staffRole: "ROOT", reason: "abc" })).status).toBe(400);
    expect((await post({ staffRole: "ADMIN", reason: "x" })).status).toBe(400);
    expect((await post({ staffRole: "ADMIN", reason: "abc" }, "not-a-uuid")).status).toBe(400);
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
  });
});

describe("OPS_PERMISSION_DENIED copy", () => {
  it("replaces the English Nest message with Vietnamese guidance", async () => {
    const { jsonFromOpsUpstream, OPS_PERMISSION_DENIED_MESSAGE } = await import(
      "@/lib/api/ops-bff-response"
    );
    const res = jsonFromOpsUpstream({
      ok: false,
      status: 403,
      message: "Missing permission: settings.write",
      errorCode: "OPS_PERMISSION_DENIED",
    } as never);
    expect(res.status).toBe(403);
    expect((await res.json()).message).toBe(OPS_PERMISSION_DENIED_MESSAGE);
  });
});
