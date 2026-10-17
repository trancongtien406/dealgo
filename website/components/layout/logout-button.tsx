"use client";

import { useState } from "react";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { useLogoutMutation } from "@/features/session/hooks";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

export function LogoutButton() {
  const logoutMutation = useLogoutMutation();
  const pending = logoutMutation.isPending;
  const [confirmOpen, setConfirmOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => {
          if (pending) {
            return;
          }
          setConfirmOpen(true);
        }}
        disabled={pending}
        className={`h-9 shrink-0 rounded-lg border border-border bg-white px-3 text-sm font-medium text-ink hover:bg-canvas hover:text-danger hover:border-danger/30 transition-colors disabled:opacity-60 cursor-pointer disabled:cursor-not-allowed ${focusRing}`}
      >
        Đăng xuất
      </button>
      <ConfirmDialog
        open={confirmOpen}
        title="Đăng xuất?"
        description="Bạn sẽ cần đăng nhập lại để tiếp tục quản trị."
        confirmLabel="Đăng xuất"
        cancelLabel="Ở lại"
        tone="danger"
        pending={pending}
        onClose={() => {
          if (!pending) {
            setConfirmOpen(false);
          }
        }}
        onConfirm={() => {
          logoutMutation.mutate(undefined, {
            onSettled: () => setConfirmOpen(false),
          });
        }}
      />
    </>
  );
}
