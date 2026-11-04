/** Nest OpsDriverCreditRefundDto: reason 5–500, bankRef 3–120 characters after trim. */
export const DRIVER_CREDIT_REFUND_REASON_MIN = 5;
export const DRIVER_CREDIT_REFUND_REASON_MAX = 500;
export const DRIVER_CREDIT_REFUND_BANK_REF_MIN = 3;
export const DRIVER_CREDIT_REFUND_BANK_REF_MAX = 120;

export type DriverCreditRefundCheck =
  | { ok: true; value: { reason: string; bankRef: string } }
  | { ok: false; message: string };

export function checkDriverCreditRefund(input: {
  reason?: unknown;
  bankRef?: unknown;
}): DriverCreditRefundCheck {
  const reason = typeof input.reason === "string" ? input.reason.trim() : "";
  if (
    reason.length < DRIVER_CREDIT_REFUND_REASON_MIN ||
    reason.length > DRIVER_CREDIT_REFUND_REASON_MAX
  ) {
    return {
      ok: false,
      message: `Lý do cần ${DRIVER_CREDIT_REFUND_REASON_MIN}–${DRIVER_CREDIT_REFUND_REASON_MAX} ký tự.`,
    };
  }
  const bankRef = typeof input.bankRef === "string" ? input.bankRef.trim() : "";
  if (
    bankRef.length < DRIVER_CREDIT_REFUND_BANK_REF_MIN ||
    bankRef.length > DRIVER_CREDIT_REFUND_BANK_REF_MAX
  ) {
    return {
      ok: false,
      message: `Mã giao dịch chuyển khoản cần ${DRIVER_CREDIT_REFUND_BANK_REF_MIN}–${DRIVER_CREDIT_REFUND_BANK_REF_MAX} ký tự.`,
    };
  }
  return { ok: true, value: { reason, bankRef } };
}
