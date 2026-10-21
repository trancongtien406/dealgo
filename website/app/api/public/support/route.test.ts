import { afterEach, describe, expect, it, vi } from "vitest";
import { POST } from "./route";

function post(body: unknown) {
  return POST(
    new Request("http://localhost:3000/api/public/support", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
  );
}

const valid = {
  role: "CUSTOMER",
  category: "FOOD",
  contact: "0901234567",
  refCode: "ORD-9876",
  content: "Đơn hàng đồ ăn bị thiếu một phần cơm gà.",
};

describe("Public Support Route POST /api/public/support", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("stores the ticket in the backend and returns its code", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ data: { code: "DG-261019-0042", createdAt: "2026-10-19T04:00:00.000Z" } }),
        { status: 201 },
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const res = await post(valid);
    expect(res.status).toBe(201);
    const json = await res.json();
    expect(json).toEqual({
      success: true,
      data: { ticketCode: "DG-261019-0042", createdAt: "2026-10-19T04:00:00.000Z" },
    });
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toMatch(/\/v1\/public\/support\/tickets$/);
    expect(JSON.parse(String(init.body))).toEqual({
      role: "CUSTOMER",
      category: "FOOD",
      description: valid.content,
      contact: "0901234567",
      externalRef: "ORD-9876",
    });
  });

  it("maps the per-contact daily cap to a Vietnamese 429", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ errorCode: "SUPPORT_CONTACT_LIMIT_REACHED" }), {
          status: 429,
        }),
      ),
    );
    const res = await post(valid);
    expect(res.status).toBe(429);
    expect((await res.json()).message).toContain("24 giờ");
  });

  it("does not fake success when the backend is down", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("ECONNREFUSED")));
    const res = await post(valid);
    expect(res.status).toBe(503);
    expect((await res.json()).success).toBe(false);
  });

  it("returns 400 when content is shorter than 10 characters", async () => {
    const res = await post({ ...valid, content: "Ngắn quá" });
    expect(res.status).toBe(400);
    expect((await res.json()).message).toContain("tối thiểu 10 ký tự");
  });

  it("returns 400 when contact info is missing or the category is unknown", async () => {
    expect((await post({ ...valid, contact: "" })).status).toBe(400);
    expect((await post({ ...valid, category: "TRIP_ISSUE" })).status).toBe(400);
  });
});
