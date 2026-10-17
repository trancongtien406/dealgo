import { describe, expect, it } from "vitest";
import { POST } from "./route";

describe("Public Support Route POST /api/public/support", () => {
  it("returns 200 with inquiryId when payload is valid", async () => {
    const req = new Request("http://localhost:3000/api/public/support", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        role: "CUSTOMER",
        topic: "FOOD",
        contact: "0901234567",
        refCode: "ORD-9876",
        content: "Đơn hàng đồ ăn bị thiếu một phần cơm gà.",
      }),
    });

    const res = await POST(req);
    expect(res.status).toBe(200);

    const json = await res.json();
    expect(json.success).toBe(true);
    expect(json.data.inquiryId).toMatch(/^INQ-/);
    expect(json.data.topic).toBe("FOOD");
    expect(json.data.message).toContain(
      "Mã tra soát phản ánh đã được hệ thống DealGo ghi nhận",
    );
  });

  it("returns 400 when content is shorter than 10 characters", async () => {
    const req = new Request("http://localhost:3000/api/public/support", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contact: "0901234567",
        content: "Ngắn quá",
      }),
    });

    const res = await POST(req);
    expect(res.status).toBe(400);

    const json = await res.json();
    expect(json.success).toBe(false);
    expect(json.message).toContain("tối thiểu 10 ký tự");
  });

  it("returns 400 when contact info is missing or empty", async () => {
    const req = new Request("http://localhost:3000/api/public/support", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contact: "",
        content: "Đơn hàng đồ ăn bị thiếu một phần cơm gà.",
      }),
    });

    const res = await POST(req);
    expect(res.status).toBe(400);

    const json = await res.json();
    expect(json.success).toBe(false);
    expect(json.message).toContain("số điện thoại hoặc email");
  });

  it("returns 400 when request body is not JSON", async () => {
    const req = new Request("http://localhost:3000/api/public/support", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "not-json",
    });

    const res = await POST(req);
    expect(res.status).toBe(400);
  });
});
