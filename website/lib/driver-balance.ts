/** Driver ↔ DealGo balance shown to Ops. */
export type DriverBalanceAdjustment = {
  id: string;
  kind: string;
  amountVnd: number;
  refType: string;
  refId: string;
  occurredAt: string;
};

/** Dropped / (dropped + completed) jobs over a window. */
export type DriverCancelRate = {
  windowDays: number;
  cancelled: number;
  completed: number;
  percent: number;
  warnPercent: number;
  warn: boolean;
};

export type DriverBalance = {
  feesVnd: number;
  adjustmentsVnd: number;
  amountVnd: number;
  settledThrough: string | null;
  limitVnd: number;
  blocked: boolean;
  cancelRate: DriverCancelRate | null;
  adjustments: DriverBalanceAdjustment[];
};

const KIND_LABELS: Record<string, string> = {
  CUSTOMER_FEE_COLLECTED: "Thu hộ phí huỷ / không đến (nộp lại DealGo)",
  CUSTOMER_FEE_PAYOUT: "Phí huỷ / không đến trả cho tài xế",
  FOOD_DISCOUNT_REIMBURSED: "DealGo hoàn phần voucher đồ ăn",
  FOOD_FAILED_REIMBURSED: "DealGo hoàn tiền món (đơn giao thất bại)",
  OPS_DRIVER_PAYMENT: "Tài xế nộp tiền / nạp trước",
  OPS_DRIVER_PAYOUT: "DealGo chi trả cho tài xế",
};

export type DriverPaymentDirection = "DRIVER_PAID" | "DEALGO_PAID";

export type DriverPaymentCheck =
  | { ok: true; value: { direction: DriverPaymentDirection; amountVnd: number } }
  | { ok: false; message: string };

/** Same bounds as the backend DTO (1,000 – 50,000,000 VND, whole đồng). */
export function checkDriverPayment(input: {
  direction?: unknown;
  amountVnd?: unknown;
}): DriverPaymentCheck {
  if (input.direction !== "DRIVER_PAID" && input.direction !== "DEALGO_PAID") {
    return { ok: false, message: "Chọn chiều thanh toán." };
  }
  const amount = typeof input.amountVnd === "number" ? input.amountVnd : Number(input.amountVnd);
  if (!Number.isInteger(amount) || amount < 1000 || amount > 50_000_000) {
    return { ok: false, message: "Số tiền từ 1.000 đến 50.000.000 ₫." };
  }
  return { ok: true, value: { direction: input.direction, amountVnd: amount } };
}

export function adjustmentKindLabel(kind: string): string {
  return KIND_LABELS[kind] ?? kind;
}

const num = (v: unknown) => (typeof v === "number" ? v : Number(v)) || 0;

/** Defensive parse of the BFF payload (numbers may arrive as strings). */
export function parseDriverBalance(raw: unknown): DriverBalance {
  const d = (raw ?? {}) as Record<string, unknown>;
  const rows = Array.isArray(d.adjustments) ? d.adjustments : [];
  return {
    feesVnd: num(d.feesVnd),
    adjustmentsVnd: num(d.adjustmentsVnd),
    amountVnd: num(d.amountVnd),
    settledThrough:
      typeof d.settledThrough === "string" ? d.settledThrough : null,
    limitVnd: num(d.limitVnd),
    blocked: d.blocked === true,
    cancelRate: parseCancelRate(d.cancelRate),
    adjustments: rows.map((r) => {
      const row = (r ?? {}) as Record<string, unknown>;
      return {
        id: String(row.id ?? ""),
        kind: String(row.kind ?? ""),
        amountVnd: num(row.amountVnd),
        refType: String(row.refType ?? ""),
        refId: String(row.refId ?? ""),
        occurredAt: String(row.occurredAt ?? ""),
      };
    }),
  };
}

/** Share of the debt limit used, 0..100 (0 when the limit is disabled). */
export function debtUsagePercent(
  b: Pick<DriverBalance, "amountVnd" | "limitVnd">,
): number {
  if (b.limitVnd <= 0 || b.amountVnd <= 0) return 0;
  return Math.min(100, Math.round((b.amountVnd / b.limitVnd) * 100));
}

function parseCancelRate(raw: unknown): DriverCancelRate | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  return {
    windowDays: num(r.windowDays),
    cancelled: num(r.cancelled),
    completed: num(r.completed),
    percent: num(r.percent),
    warnPercent: num(r.warnPercent),
    warn: r.warn === true,
  };
}
