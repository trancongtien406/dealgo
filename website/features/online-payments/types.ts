/** Online payment intents (MoMo / ZaloPay / VNPay …) as returned by /v1/ops/payment-intents. */
export const INTENT_STATUSES = [
  "CREATED",
  "PENDING_REDIRECT",
  "CAPTURED",
  "FAILED",
  "EXPIRED",
  "REFUND_PENDING",
  "REFUNDED",
] as const;
export type IntentStatus = (typeof INTENT_STATUSES)[number];

export const INTENT_PROVIDERS = ["momo", "zalopay", "vnpay", "shopeepay", "card", "applepay", "wallet"] as const;
export type IntentProvider = (typeof INTENT_PROVIDERS)[number];

export type IntentEntityType = "RIDE" | "FOOD_ORDER";

export type OpsPaymentIntent = {
  id: string;
  entityType: IntentEntityType;
  entityId: string;
  methodCode: string | null;
  provider: IntentProvider | "sandbox";
  status: IntentStatus;
  amountVnd: number;
  refundedVnd: number;
  providerRef: string | null;
  failureReason: string | null;
  settled: boolean;
  updatedAt: string;
};

export type OpsPaymentRefund = {
  id: string;
  amountVnd: number;
  status: "PENDING" | "SUCCEEDED" | "REJECTED";
  requestId: string;
  providerRefundRef: string | null;
  reason: string;
  actorUserId: string;
  afterSettlement: boolean;
  createdAt: string;
};

export type OpsPaymentIntentDetail = OpsPaymentIntent & {
  providerTransId: string | null;
  providerPayDate: string | null;
  createdAt: string;
  settledAt: string | null;
  lastReconciledAt: string | null;
  reconcileAttempts: number;
  refundableVnd: number;
  refunds: OpsPaymentRefund[];
};

export type IntentListFilter = {
  status: IntentStatus | null;
  provider: IntentProvider | null;
  entityType: IntentEntityType | null;
  q: string;
  limit: number;
};

export type ReconcileSummary = {
  checked: number;
  captured: number;
  failed: number;
  expired: number;
  pending: number;
  skipped: number;
};
