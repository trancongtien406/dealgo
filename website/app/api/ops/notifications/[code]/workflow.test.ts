import { beforeEach, describe, expect, it, vi } from "vitest";
import { campaignActionsFor } from "@/features/notifications/components/notifications-campaign-modal";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { POST: SUBMIT } = await import("./submit/route");
const { POST: CANCEL } = await import("./cancel/route");

function req(path: string, body?: unknown) {
  return new Request(`http://localhost:3000${path}`, {
    method: "POST",
    headers: {
      Origin: "http://localhost:3000",
      Host: "localhost:3000",
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

const ctx = { params: Promise.resolve({ code: "TB-261020-001" }) };

describe("campaign workflow (DEC-PROD-044)", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
    fetchOpsUpstream.mockResolvedValue({ ok: true, status: 200, data: {} });
  });

  it("offers the transitions Nest allows per status", () => {
    expect(campaignActionsFor("DRAFT")).toEqual(["submit", "cancel"]);
    expect(campaignActionsFor("PENDING_APPROVAL")).toEqual(["approve", "reject", "cancel"]);
    expect(campaignActionsFor("RUNNING")).toEqual(["cancel"]);
    expect(campaignActionsFor("SENT")).toEqual([]);
    expect(campaignActionsFor("CANCELLED")).toEqual([]);
  });

  it("submits a draft with or without a note", async () => {
    expect((await SUBMIT(req("/api/ops/notifications/TB-261020-001/submit"), ctx)).status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenLastCalledWith({
      method: "POST",
      path: "/v1/ops/notifications/TB-261020-001/submit",
      body: {},
    });
    await SUBMIT(req("/api/ops/notifications/TB-261020-001/submit", { reason: "sẵn sàng" }), ctx);
    expect(fetchOpsUpstream).toHaveBeenLastCalledWith(
      expect.objectContaining({ body: { reason: "sẵn sàng" } }),
    );
  });

  it("requires a reason to cancel", async () => {
    const missing = await CANCEL(req("/api/ops/notifications/TB-261020-001/cancel", {}), ctx);
    expect(missing.status).toBe(400);
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
    const ok = await CANCEL(
      req("/api/ops/notifications/TB-261020-001/cancel", { reason: "sai nội dung" }),
      ctx,
    );
    expect(ok.status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenCalledWith({
      method: "POST",
      path: "/v1/ops/notifications/TB-261020-001/cancel",
      body: { reason: "sai nội dung" },
    });
  });
});
