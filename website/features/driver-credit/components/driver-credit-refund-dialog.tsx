"use client";

import { useId, useState } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import {
  DRIVER_CREDIT_REFUND_BANK_REF_MAX,
  DRIVER_CREDIT_REFUND_REASON_MAX,
  checkDriverCreditRefund,
} from "@/lib/api/ops-driver-credit-body";
import { vnd } from "@/lib/admin-format";

type Props = {
  open: boolean;
  driverLabel: string;
  refundableVnd: number;
  onClose: () => void;
  /** Throw to keep the dialog open; the message is shown inline. */
  onSubmit: (input: { reason: string; bankRef: string }) => Promise<void>;
};

/** Records the real bank transfer; the audit log needs both the reason and the transfer reference. */
export function DriverCreditRefundDialog({
  open,
  driverLabel,
  refundableVnd,
  onClose,
  onSubmit,
}: Props) {
  const titleId = useId();
  const reasonId = useId();
  const bankRefId = useId();
  const [reason, setReason] = useState("");
  const [bankRef, setBankRef] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [wasOpen, setWasOpen] = useState(open);
  if (open !== wasOpen) {
    setWasOpen(open);
    setReason("");
    setBankRef("");
    setError(null);
  }
  if (!open) {
    return null;
  }

  const submit = async () => {
    const checked = checkDriverCreditRefund({ reason, bankRef });
    if (!checked.ok) {
      setError(checked.message);
      return;
    }
    setPending(true);
    setError(null);
    try {
      await onSubmit(checked.value);
      onClose();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Hoàn tiền thất bại. Thử lại.",
      );
    } finally {
      setPending(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-4 sm:items-center"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !pending) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        data-testid="driver-credit-refund-dialog"
        className="w-full max-w-md rounded-2xl border border-border bg-white p-4 shadow-lg"
      >
        <h2 id={titleId} className="text-base font-semibold text-ink">
          Hoàn tiền tạm ứng còn lại
        </h2>
        <p className="mt-1 text-sm text-muted">
          Chuyển khoản {vnd(refundableVnd)} cho {driverLabel}. Hệ thống chỉ ghi
          nhận sau khi bạn đã thực hiện lệnh chuyển tiền thật.
        </p>
        <label
          htmlFor={reasonId}
          className="mt-4 block text-xs font-medium text-muted"
        >
          Lý do (ghi nhật ký kiểm toán)
        </label>
        <textarea
          id={reasonId}
          rows={3}
          maxLength={DRIVER_CREDIT_REFUND_REASON_MAX}
          disabled={pending}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink disabled:opacity-60 ${focusRing}`}
        />
        <label
          htmlFor={bankRefId}
          className="mt-3 block text-xs font-medium text-muted"
        >
          Mã giao dịch chuyển khoản
        </label>
        <input
          id={bankRefId}
          type="text"
          autoComplete="off"
          maxLength={DRIVER_CREDIT_REFUND_BANK_REF_MAX}
          disabled={pending}
          value={bankRef}
          onChange={(event) => setBankRef(event.target.value)}
          placeholder="VD: VCB-20261103-001234"
          className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted disabled:opacity-60 ${focusRing}`}
        />
        {error ? (
          <p role="alert" className="mt-2 text-sm text-danger">
            {error}
          </p>
        ) : null}
        <div className="mt-4 flex justify-end gap-2">
          <button
            type="button"
            disabled={pending}
            onClick={onClose}
            className={`h-10 rounded-xl border border-border bg-white px-4 text-sm font-medium text-ink disabled:opacity-60 ${focusRing}`}
          >
            Huỷ
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => void submit()}
            className={`h-10 rounded-xl bg-danger px-4 text-sm font-semibold text-white hover:bg-danger/90 disabled:opacity-60 ${focusRing}`}
          >
            {pending ? "Đang xử lý…" : "Xác nhận đã chuyển"}
          </button>
        </div>
      </div>
    </div>
  );
}
