"use client";

import { useId, useState } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import { toast } from "@/components/ui/toast";
import { ApiError } from "@/lib/api/errors";
import {
  checkOpsPasswordReset,
  OPS_RESET_PASSWORD_MIN,
} from "@/lib/api/ops-password-reset-body";
import { useResetStaffPasswordMutation } from "@/features/staff/hooks";

type Props = {
  person: { id: string; name: string; email: string } | null;
  onClose: () => void;
};

/** DEC-PROD-036: super-admin sets a temporary password for another operator. */
export function StaffPasswordResetDialog({ person, onClose }: Props) {
  const titleId = useId();
  const pwId = useId();
  const confirmId = useId();
  const reasonId = useId();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const mutation = useResetStaffPasswordMutation();
  const pending = mutation.isPending;

  const [prevId, setPrevId] = useState<string | null>(null);
  const currentId = person?.id ?? null;
  if (currentId !== prevId) {
    setPrevId(currentId);
    setPassword("");
    setConfirm("");
    setReason("");
    setError(null);
  }

  if (!person) {
    return null;
  }

  const submit = async () => {
    const checked = checkOpsPasswordReset({
      newPassword: password,
      confirmPassword: confirm,
      reason,
    });
    if (!checked.ok) {
      setError(checked.message);
      return;
    }
    setError(null);
    try {
      await mutation.mutateAsync({ id: person.id, ...checked.value });
      toast.success(
        `Đã đặt lại mật khẩu cho ${person.name}. Mọi phiên Admin của tài khoản đã bị đăng xuất.`,
      );
      onClose();
    } catch (err) {
      const message =
        err instanceof ApiError || err instanceof Error
          ? err.message
          : "Thao tác thất bại. Thử lại.";
      setError(message);
      toast.error(message);
    }
  };

  const inputClass = `mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink disabled:opacity-60 ${focusRing}`;

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
        data-testid="staff-password-reset-dialog"
        className="w-full max-w-md rounded-2xl border border-border bg-white p-4 shadow-lg"
      >
        <h2 id={titleId} className="text-base font-semibold text-ink">
          Đặt lại mật khẩu Admin
        </h2>
        <p className="mt-1 text-sm text-muted">
          {person.name} ({person.email}). Tài khoản sẽ bị đăng xuất khỏi mọi
          phiên và phải đăng nhập lại. Thao tác được ghi nhật ký kiểm toán.
        </p>
        <label htmlFor={pwId} className="mt-4 block text-xs font-medium text-muted">
          Mật khẩu tạm thời (tối thiểu {OPS_RESET_PASSWORD_MIN} ký tự)
        </label>
        <input
          id={pwId}
          type="password"
          autoComplete="new-password"
          disabled={pending}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className={inputClass}
        />
        <label htmlFor={confirmId} className="mt-3 block text-xs font-medium text-muted">
          Nhập lại mật khẩu
        </label>
        <input
          id={confirmId}
          type="password"
          autoComplete="new-password"
          disabled={pending}
          value={confirm}
          onChange={(event) => setConfirm(event.target.value)}
          className={inputClass}
        />
        <label htmlFor={reasonId} className="mt-3 block text-xs font-medium text-muted">
          Lý do (ghi vào nhật ký)
        </label>
        <textarea
          id={reasonId}
          rows={2}
          disabled={pending}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder="VD: Quên mật khẩu, đã xác minh qua điện thoại"
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
            disabled={pending}
            onClick={() => {
              void submit();
            }}
            className={`inline-flex h-10 items-center rounded-xl border border-transparent bg-danger px-3 text-sm font-semibold text-white disabled:opacity-40 ${focusRing}`}
          >
            {pending ? "Đang xử lý…" : "Đặt lại mật khẩu"}
          </button>
        </div>
      </div>
    </div>
  );
}
