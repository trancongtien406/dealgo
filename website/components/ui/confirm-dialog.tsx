"use client";

import { useEffect, useId, useRef, type ReactNode } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";

export type ConfirmDialogProps = {
  open: boolean;
  title: string;
  description?: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: "danger" | "brand";
  pending?: boolean;
  onConfirm: () => void | Promise<void>;
  onClose: () => void;
};

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = "Xác nhận",
  cancelLabel = "Hủy",
  tone = "danger",
  pending = false,
  onConfirm,
  onClose,
}: ConfirmDialogProps) {
  const titleId = useId();
  const confirmRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }
    const frame = window.requestAnimationFrame(() => {
      confirmRef.current?.focus();
    });
    return () => window.cancelAnimationFrame(frame);
  }, [open]);

  useEffect(() => {
    if (!open) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !pending) {
        onClose();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, pending, onClose]);

  if (!open) {
    return null;
  }

  const confirmClass =
    tone === "brand"
      ? "border-transparent bg-brand text-white"
      : "border-transparent bg-danger text-white";

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
        className="w-full max-w-md rounded-2xl border border-border bg-white p-4 shadow-lg"
      >
        <h2 id={titleId} className="text-base font-semibold text-ink">
          {title}
        </h2>
        {description ? (
          <div className="mt-1 text-sm text-muted">{description}</div>
        ) : null}
        <div className="mt-4 flex flex-wrap justify-end gap-2">
          <button
            type="button"
            disabled={pending}
            onClick={onClose}
            className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink disabled:opacity-50 ${focusRing}`}
          >
            {cancelLabel}
          </button>
          <button
            ref={confirmRef}
            type="button"
            disabled={pending}
            onClick={() => {
              void onConfirm();
            }}
            className={`inline-flex h-10 items-center rounded-xl border px-3 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-40 ${confirmClass} ${focusRing}`}
          >
            {pending ? "Đang xử lý…" : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
