import { describe, expect, it } from "vitest";
import {
  refundStatusLabel,
  refundStatusTone,
  resolveRefundOrderRoute,
} from "@/features/refunds/mappers";

describe("refundStatusLabel", () => {
  it("maps API refund codes to Vietnamese UI labels", () => {
    expect(refundStatusLabel("AWAITING_REVIEW")).toBe("Chờ kiểm tra");
    expect(refundStatusLabel("REFUNDED")).toBe("Đã hoàn tiền");
    expect(refundStatusLabel("REJECTED")).toBe("Từ chối");
  });
});

describe("refundStatusTone", () => {
  it("returns a tone for each known refund status", () => {
    expect(refundStatusTone("PROCESSING")).toBe("delivery");
    expect(refundStatusTone("EVIDENCE_REQUESTED")).toBe("brand");
  });
});

describe("resolveRefundOrderRoute", () => {
  it("routes ride orders correctly", () => {
    const route = resolveRefundOrderRoute("Chuyến xe", "DGX-240610-1024");
    expect(route.href).toBe("/rides/DGX-240610-1024");
    expect(route.label).toContain("chuyến xe");
  });

  it("routes food orders correctly", () => {
    const route = resolveRefundOrderRoute("Đồ ăn", "FA-240610-0892");
    expect(route.href).toBe("/food-orders/FA-240610-0892");
    expect(route.label).toContain("đơn đồ ăn");
  });

  it("routes delivery orders correctly", () => {
    const route = resolveRefundOrderRoute("Giao hàng", "GH-240610-0142");
    expect(route.href).toBe("/deliveries/GH-240610-0142");
    expect(route.label).toContain("đơn giao hàng");
  });

  it("handles unknown service cleanly without crashing or false links", () => {
    const route = resolveRefundOrderRoute("UNKNOWN", "UNKNOWN-123");
    expect(route.href).toBeNull();
    expect(route.label).toContain("UNKNOWN-123");
  });
});
