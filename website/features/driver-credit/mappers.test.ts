import { describe, expect, it } from "vitest";
import {
  canReconcile,
  canRefund,
  consumedRatio,
  driverDisplayName,
  providerLabel,
  topUpMemo,
  topUpStatusLabel,
  topUpStatusTone,
} from "@/features/driver-credit/mappers";
import type { DriverTopUp } from "@/features/driver-credit/types";

function topUp(overrides: Partial<DriverTopUp> = {}): DriverTopUp {
  return {
    id: "t1",
    driverId: "11111111-2222-4333-8444-555555555555",
    driverName: "Nguyễn Văn A",
    driverPhone: "0901234567",
    amountVnd: 100_000,
    remainingVnd: 100_000,
    consumedVnd: 0,
    refundedVnd: 0,
    orderCode: 9911,
    provider: "PAYOS",
    providerRef: null,
    providerTransId: null,
    status: "PAID",
    checkoutUrl: null,
    qrCode: null,
    expiresAt: null,
    paidAt: "2026-11-03T03:00:00.000Z",
    createdAt: "2026-11-03T02:50:00.000Z",
    failureReason: null,
    refundedAt: null,
    refundBankRef: null,
    refundReason: null,
    ...overrides,
  };
}

describe("driver credit mappers", () => {
  it("defaults unknown providers and statuses without crashing the board", () => {
    expect(providerLabel("PAYOS")).toBe("PayOS");
    expect(providerLabel("SOMEFUTURE")).toBe("SOMEFUTURE");
    expect(topUpStatusLabel("PAID")).toBe("Đã ghi có");
    expect(topUpStatusTone("FAILED")).toBe("danger");
  });

  it("shows the bank memo the driver sees", () => {
    expect(topUpMemo(topUp())).toBe("NAP9911");
  });

  it("falls back to an id prefix when the driver name is missing", () => {
    expect(driverDisplayName(topUp({ driverName: "  " }))).toBe("11111111");
  });

  it("only reconciles pending and only refunds paid credit with something left", () => {
    expect(canReconcile(topUp({ status: "PENDING" }))).toBe(true);
    expect(canReconcile(topUp({ status: "PAID" }))).toBe(false);
    expect(canRefund(topUp())).toBe(true);
    expect(canRefund(topUp({ remainingVnd: 0 }))).toBe(false);
    expect(canRefund(topUp({ status: "PENDING" }))).toBe(false);
  });

  it("clamps the consumption bar to 0..1", () => {
    expect(consumedRatio(topUp({ consumedVnd: 25_000 }))).toBe(0.25);
    expect(consumedRatio(topUp({ consumedVnd: 400_000 }))).toBe(1);
    expect(consumedRatio(topUp({ amountVnd: 0, consumedVnd: 10 }))).toBe(0);
  });
});
