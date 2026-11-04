export type DriverTopUpStatus =
  | "PENDING"
  | "PAID"
  | "EXPIRED"
  | "CANCELLED"
  | "REFUND_PENDING"
  | "REFUNDED"
  | "FAILED";

export type DriverTopUp = {
  id: string;
  driverId: string;
  driverName: string | null;
  driverPhone: string | null;
  amountVnd: number;
  remainingVnd: number;
  consumedVnd: number;
  refundedVnd: number;
  orderCode: number;
  provider: string;
  providerRef: string | null;
  providerTransId: string | null;
  status: DriverTopUpStatus;
  checkoutUrl: string | null;
  qrCode: string | null;
  expiresAt: string | null;
  paidAt: string | null;
  createdAt: string;
  failureReason: string | null;
  refundedAt: string | null;
  refundBankRef: string | null;
  refundReason: string | null;
};

export type DriverCreditSummary = {
  pendingCount: number;
  pendingVnd: number;
  paidTodayVnd: number;
  refundedVnd: number;
  outstandingCreditVnd: number;
};

export type DriverTopUpFilter = {
  status?: string | null;
  driverId?: string | null;
  limit?: number;
};
