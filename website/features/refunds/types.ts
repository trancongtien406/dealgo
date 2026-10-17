export const REFUND_STATUSES = [
  "AWAITING_REVIEW",
  "NEEDS_MORE_INFO",
  "PROCESSING",
  "REFUNDED",
  "REJECTED",
  "EVIDENCE_REQUESTED",
] as const;
export type RefundStatus = (typeof REFUND_STATUSES)[number];

export type RefundRequest = {
  code: string;
  orderCode: string;
  customer: string;
  amount: number;
  reason: string;
  service: string;
  status: RefundStatus;
  createdAt: string;
  paymentId: string;
  originalAmount: number;
  assignee: string;
};
