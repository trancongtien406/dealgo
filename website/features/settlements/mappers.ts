import type { StatusTone } from "@/lib/admin-format";
import type { NestSettlementBatch } from "@/features/settlements/nest-types";
import type {
  SettlementLine,
  SettlementLineStatus,
} from "@/features/settlements/types";

const labels: Record<SettlementLineStatus, string> = {
  AWAITING_RECONCILE: "Chờ đối soát",
  ELIGIBLE: "Đủ điều kiện",
  PROCESSING: "Đang xử lý",
};
const tones: Record<SettlementLineStatus, StatusTone> = {
  AWAITING_RECONCILE: "food",
  ELIGIBLE: "success",
  PROCESSING: "delivery",
};

export function settlementLineStatusLabel(status: SettlementLineStatus) {
  return labels[status];
}
export function settlementLineStatusTone(status: SettlementLineStatus) {
  return tones[status];
}

/**
 * Nest settlements are COD journal buckets per Vietnam business day (Asia/Ho_Chi_Minh); no payout.
 * Map into SettlementLine rows for the existing board table.
 */
export function mapNestSettlementBatchToLine(
  batch: NestSettlementBatch,
): SettlementLine {
  const kinds = batch.entityTypes
    .map((type) => (type === "RIDE" ? "Ride" : "Food"))
    .join("+");
  return {
    kind: kinds || "COD",
    ref: `DAY-${batch.day}`,
    at: batch.day,
    revenue: batch.totalAmountVnd,
    fee: 0,
    provisional: batch.totalAmountVnd,
    status: "AWAITING_RECONCILE",
  };
}
