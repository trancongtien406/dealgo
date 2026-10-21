"use client";

import { useId, useState } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import { checkOpsReason, OPS_REASON_MAX } from "@/lib/api/ops-reason-body";

type Props = {
  open: boolean;
  title: string;
  description: string;
  confirmLabel: string;
  tone?: "brand" | "danger";
  testId?: string;
  onClose: () => void;
  /** Throw to keep the dialog open; the message is shown inline. */
  onSubmit: (reason: string) => Promise<void>;
};

/** Small audited-action dialog: one required reason (3–500 chars), confirm / cancel. */
export function ReasonDialog({
  open,
  title,
  description,
  confirmLabel,
  tone = "brand",
  testId,
  onClose,
  onSubmit,
}: Props) {
  const titleId = useId();
  const reasonId = useId();
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [wasOpen, setWasOpen] = useState(open);
  if (open !== wasOpen) {
    setWasOpen(open);
    setReason("");
    setError(null);
  }
  if (!open) {
    return null;
  }

  const submit = async () => {
    const checked = checkOpsReason({ reason });
    if (!checked.ok) {
      setError(checked.message);
      return;
    }
    setPending(true);
    setError(null);
    try {
      await onSubmit(checked.value.reason);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Thao tác thất bại. Thử lại.");
    } finally {
      setPending(false);
    }
  };

  const confirmClass =
    tone === "danger"
      ? "bg-danger text-white hover:bg-danger/90"
      : "bg-brand text-white hover:bg-brand/90";

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
        data-testid={testId}
        className="w-full max-w-md rounded-2xl border border-border bg-white p-4 shadow-lg"
      >
        <h2 id={titleId} className="text-base font-semibold text-ink">
          {title}
        </h2>
        <p className="mt-1 text-sm text-muted">{description}</p>
        <label htmlFor={reasonId} className="mt-4 block text-xs font-medium text-muted">
          Lý do (ghi nhật ký kiểm toán)
        </label>
        <textarea
          id={reasonId}
          rows={3}
          maxLength={OPS_REASON_MAX}
          disabled={pending}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink disabled:opacity-60 ${focusRing}`}
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
            className={`h-10 rounded-xl px-4 text-sm font-semibold disabled:opacity-60 ${confirmClass} ${focusRing}`}
          >
            {pending ? "Đang xử lý…" : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
