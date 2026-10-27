/** (OPEN-018) Store commission statement by Vietnam day (Ops view). */
export type MerchantStatementTotals = {
  orderCount: number;
  grossVnd: number;
  merchantFundedVnd: number;
  cashReceivedVnd: number;
  commissionVnd: number;
  netVnd: number;
};

export type MerchantSettlementRecord = {
  id: string;
  periodStart: string;
  periodEnd: string;
  orderCount: number;
  commissionVnd: number;
  netVnd: number;
  note: string | null;
  createdAt: string;
};

export type MerchantStatement = {
  from: string;
  to: string;
  commissionPercentNow: number;
  /** MERCHANT_SETTLEMENT_CYCLE_DAYS at read time (0 when an older backend omits it). */
  settlementCycleDays: number;
  totals: MerchantStatementTotals;
  days: Array<MerchantStatementTotals & { date: string }>;
  settlements: MerchantSettlementRecord[];
  unsettledCommissionVnd: number;
};

/** Same cap as the backend (MERCHANT_STATEMENT_MAX_DAYS). */
export const MERCHANT_STATEMENT_MAX_DAYS = 31;
const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

function num(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : 0;
}

function str(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function totals(raw: unknown): MerchantStatementTotals {
  const r = (raw ?? {}) as Record<string, unknown>;
  return {
    orderCount: num(r.orderCount),
    grossVnd: num(r.grossVnd),
    merchantFundedVnd: num(r.merchantFundedVnd),
    cashReceivedVnd: num(r.cashReceivedVnd),
    commissionVnd: num(r.commissionVnd),
    netVnd: num(r.netVnd),
  };
}

export function parseMerchantStatement(raw: unknown): MerchantStatement {
  const r = (raw ?? {}) as Record<string, unknown>;
  const days = Array.isArray(r.days) ? r.days : [];
  const settlements = Array.isArray(r.settlements) ? r.settlements : [];
  return {
    from: str(r.from),
    to: str(r.to),
    commissionPercentNow: num(r.commissionPercentNow),
    settlementCycleDays: num(r.settlementCycleDays),
    totals: totals(r.totals),
    days: days.map((day) => ({
      ...totals(day),
      date: str((day as Record<string, unknown>).date),
    })),
    settlements: settlements.map((row) => {
      const s = row as Record<string, unknown>;
      return {
        id: str(s.id),
        periodStart: str(s.periodStart),
        periodEnd: str(s.periodEnd),
        orderCount: num(s.orderCount),
        commissionVnd: num(s.commissionVnd),
        netVnd: num(s.netVnd),
        note:
          typeof s.note === "string" && s.note.trim() ? s.note.trim() : null,
        createdAt: str(s.createdAt),
      };
    }),
    unsettledCommissionVnd: num(r.unsettledCommissionVnd),
  };
}

/** YYYY-MM-DD of an instant in Vietnam time (UTC+7, no DST). */
export function vnDayKey(at: Date): string {
  return new Date(at.getTime() + 7 * 3_600_000).toISOString().slice(0, 10);
}

/** Default window: the last 7 closed ICT days (yesterday back 6 days). */
export function defaultStatementRange(now: Date = new Date()): {
  from: string;
  to: string;
} {
  const day = 86_400_000;
  return {
    from: vnDayKey(new Date(now.getTime() - 7 * day)),
    to: vnDayKey(new Date(now.getTime() - day)),
  };
}

export type StatementRangeCheck =
  | { ok: true; value: { from: string; to: string } }
  | { ok: false; message: string };

/** Valid ICT day range, from ≤ to, at most 31 days; `closedOnly` also needs to < today (ICT). */
export function checkStatementRange(
  input: { from?: unknown; to?: unknown },
  opts: { closedOnly?: boolean; now?: Date } = {},
): StatementRangeCheck {
  const from = str(input.from).trim();
  const to = str(input.to).trim();
  if (!DAY_KEY.test(from) || !DAY_KEY.test(to)) {
    return { ok: false, message: "Chọn ngày bắt đầu và kết thúc." };
  }
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  if (Number.isNaN(start) || Number.isNaN(end) || start > end) {
    return { ok: false, message: "Ngày bắt đầu phải trước ngày kết thúc." };
  }
  if ((end - start) / 86_400_000 + 1 > MERCHANT_STATEMENT_MAX_DAYS) {
    return {
      ok: false,
      message: `Tối đa ${MERCHANT_STATEMENT_MAX_DAYS} ngày mỗi lần.`,
    };
  }
  if (opts.closedOnly && to >= vnDayKey(opts.now ?? new Date())) {
    return {
      ok: false,
      message: "Chỉ chốt được các ngày đã qua (trước hôm nay).",
    };
  }
  return { ok: true, value: { from, to } };
}

/** Vietnamese copy for the settlement error codes (null = keep upstream text). */
export function merchantSettlementErrorMessage(
  code: string | undefined,
): string | null {
  switch (code) {
    case "FOOD_SETTLEMENT_OVERLAP":
      return "Khoảng ngày này trùng với một lần nộp đã ghi nhận.";
    case "FOOD_SETTLEMENT_PERIOD_OPEN":
      return "Chỉ chốt được các ngày đã qua (trước hôm nay).";
    case "FOOD_STORE_NOT_FOUND":
      return "Không tìm thấy cửa hàng.";
    default:
      return null;
  }
}
