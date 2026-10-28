import type { StatusTone } from "@/lib/admin-format";
import type {
  IntentListFilter,
  IntentStatus,
  OpsPaymentIntent,
  OpsPaymentRefund,
} from "@/features/online-payments/types";

export const INTENT_STATUS_LABELS: Record<IntentStatus, string> = {
  CREATED: "Mới tạo",
  PENDING_REDIRECT: "Chờ thanh toán",
  CAPTURED: "Đã thanh toán",
  FAILED: "Thất bại",
  EXPIRED: "Hết hạn",
  REFUND_PENDING: "Đang hoàn",
  REFUNDED: "Đã hoàn",
};

export function intentStatusTone(status: IntentStatus): StatusTone {
  switch (status) {
    case "CAPTURED":
      return "success";
    case "FAILED":
      return "danger";
    case "REFUND_PENDING":
    case "PENDING_REDIRECT":
    case "CREATED":
      return "delivery";
    case "REFUNDED":
      return "food";
    default:
      return "brand";
  }
}

export const PROVIDER_LABELS: Record<string, string> = {
  momo: "MoMo",
  zalopay: "ZaloPay",
  vnpay: "VNPay",
  shopeepay: "ShopeePay",
  card: "Thẻ quốc tế",
  applepay: "Apple Pay",
  wallet: "Ví DealGo",
  sandbox: "Sandbox",
};

export const REFUND_STATUS_LABELS: Record<OpsPaymentRefund["status"], string> = {
  PENDING: "Đang xử lý",
  SUCCEEDED: "Thành công",
  REJECTED: "Bị từ chối",
};

export function entityLabel(intent: Pick<OpsPaymentIntent, "entityType">): string {
  return intent.entityType === "RIDE" ? "Chuyến xe" : "Đơn đồ ăn";
}

/** Still refundable (captured − refunded) for a row; non-captured rows are 0. */
export function refundableOf(intent: Pick<OpsPaymentIntent, "status" | "amountVnd" | "refundedVnd">): number {
  if (intent.status !== "CAPTURED" && intent.status !== "REFUND_PENDING") return 0;
  return Math.max(0, intent.amountVnd - intent.refundedVnd);
}

/** Validates the ops-typed refund amount (digits, dots/commas/spaces allowed). */
export function parseRefundAmount(
  raw: string,
  refundableVnd: number,
): { ok: true; amountVnd: number } | { ok: false; message: string } {
  const digits = raw.replace(/[\s.,_]/g, "");
  if (!/^\d+$/.test(digits)) return { ok: false, message: "Nhập số tiền hợp lệ (VND)." };
  const amountVnd = Number(digits);
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    return { ok: false, message: "Số tiền phải lớn hơn 0." };
  }
  if (amountVnd > refundableVnd) {
    return { ok: false, message: `Tối đa còn hoàn được ${refundableVnd.toLocaleString("vi-VN")} đ.` };
  }
  return { ok: true, amountVnd };
}

export function intentListSearchParams(filter: IntentListFilter): URLSearchParams {
  const params = new URLSearchParams({ limit: String(filter.limit) });
  if (filter.status) params.set("status", filter.status);
  if (filter.provider) params.set("provider", filter.provider);
  if (filter.entityType) params.set("entityType", filter.entityType);
  const q = filter.q.trim();
  if (q) params.set("q", q);
  return params;
}
