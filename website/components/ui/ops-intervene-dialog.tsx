"use client";

import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import { toast } from "@/components/ui/toast";
import {
  INTERVENE_REASON_MAX,
  INTERVENE_REASON_MIN,
} from "@/lib/api/ops-intervene-body";
import { ApiError } from "@/lib/api/errors";

type InterveneKind = "cancel" | "reassign";

type InterveneCopy = { title: string; confirm: string; hint: string; success?: string };

type OpsInterveneDialogProps = {
  open: boolean;
  /** Built-in cancel/reassign copy; ignored when `labels` is set. */
  kind?: InterveneKind;
  labels?: InterveneCopy;
  confirmTone?: "danger" | "brand";
  entityLabel: string;
  pending: boolean;
  onClose: () => void;
  onConfirm: (reason: string) => Promise<void>;
};

const copy: Record<InterveneKind, InterveneCopy> = {
  cancel: {
    title: "Hủy bởi vận hành",
    confirm: "Xác nhận hủy",
    hint: "Lý do được ghi vào nhật ký kiểm toán trên máy chủ.",
  },
  reassign: {
    title: "Gỡ gán tài xế (TEST_ONLY)",
    confirm: "Xác nhận gỡ gán",
    hint: "Chỉ cho phép khi đã gán tài xế và chuyến/đơn chưa hoàn tất.",
  },
};

export function OpsInterveneDialog({
  open,
  kind = "cancel",
  labels,
  confirmTone = "danger",
  entityLabel,
  pending,
  onClose,
  onConfirm,
}: OpsInterveneDialogProps) {
  const titleId = useId();
  const reasonId = useId();
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);

  const [prevOpen, setPrevOpen] = useState(open);
  if (open !== prevOpen) {
    setPrevOpen(open);
    if (open) {
      setReason("");
      setError(null);
    }
  }

  useEffect(() => {
    if (!open) {
      return;
    }
    const frame = window.requestAnimationFrame(() => {
      inputRef.current?.focus();
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

  const dialogCopy = labels ?? copy[kind];
  const trimmed = reason.trim();
  const reasonOk =
    trimmed.length >= INTERVENE_REASON_MIN &&
    trimmed.length <= INTERVENE_REASON_MAX;
  const confirmClass =
    confirmTone === "brand"
      ? "border-transparent bg-brand text-white"
      : "border-transparent bg-danger text-white";

  const submit = async () => {
    if (!reasonOk || pending) {
      return;
    }
    setError(null);
    try {
      await onConfirm(trimmed);
      const success = labels
        ? labels.success
        : kind === "cancel"
          ? "Đã hủy thành công."
          : "Đã gỡ gán thành công.";
      if (success) {
        toast.success(success);
      }
      onClose();
    } catch (err) {
      const message = errorMessage(err);
      setError(message);
      toast.error(message);
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
        className="w-full max-w-md rounded-2xl border border-border bg-white p-4 shadow-lg"
      >
        <h2 id={titleId} className="text-base font-semibold text-ink">
          {dialogCopy.title}
        </h2>
        <p className="mt-1 text-sm text-muted">
          {entityLabel}. {dialogCopy.hint}
        </p>
        <label
          htmlFor={reasonId}
          className="mt-4 block text-xs font-medium text-muted"
        >
          Lý do ({INTERVENE_REASON_MIN}–{INTERVENE_REASON_MAX} ký tự)
        </label>
        <textarea
          ref={inputRef}
          id={reasonId}
          rows={3}
          disabled={pending}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder="Nhập lý do can thiệp…"
          className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink placeholder:text-muted disabled:opacity-60 ${focusRing}`}
        />
        {error ? (
          <p role="alert" className="mt-2 text-sm text-danger">
            {error}
          </p>
        ) : null}
        <div className="mt-4 flex flex-wrap justify-end gap-2">
          <button
            type="button"
            disabled={pending}
            onClick={onClose}
            className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink disabled:opacity-50 ${focusRing}`}
          >
            Đóng
          </button>
          <button
            type="button"
            disabled={pending || !reasonOk}
            onClick={() => {
              void submit();
            }}
            className={`inline-flex h-10 items-center rounded-xl border px-3 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-40 ${confirmClass} ${focusRing}`}
          >
            {pending ? "Đang xử lý…" : dialogCopy.confirm}
          </button>
        </div>
      </div>
    </div>
  );
}

export function OpsInterveneActionButton({
  tone = "danger",
  disabled,
  pending,
  onClick,
  children,
}: {
  tone?: "danger" | "brand";
  disabled?: boolean;
  pending?: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  const toneClass =
    tone === "danger"
      ? "border-danger/40 bg-white text-danger"
      : "border-brand/30 bg-white text-brand";
  return (
    <button
      type="button"
      disabled={disabled || pending}
      onClick={onClick}
      className={`inline-flex h-10 shrink-0 items-center justify-center gap-2 rounded-xl border px-3 text-sm font-medium disabled:cursor-not-allowed disabled:opacity-40 ${toneClass} ${focusRing}`}
    >
      {children}
    </button>
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    return error.message;
  }
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return "Thao tác thất bại. Thử lại.";
}
