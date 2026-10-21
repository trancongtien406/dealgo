"use client";

import { useState } from "react";
import { focusRing, StatusChip } from "@/components/ui/admin-list-ui";
import { DetailSection } from "@/components/ui/admin-detail-ui";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { toast } from "@/components/ui/toast";
import { useCancelAccountDeletionMutation } from "@/features/account-deletion/hooks";
import {
  accountDeletionLabel,
  accountDeletionSummary,
  canRestoreAccount,
  type AccountDeletionInfo,
} from "@/lib/account-deletion";

/** S027 status on customer/driver detail; restore button while inside the grace period. */
export function AccountDeletionCard({
  userId,
  name,
  deletion,
}: {
  userId: string;
  name: string;
  deletion: AccountDeletionInfo | null | undefined;
}) {
  const [open, setOpen] = useState(false);
  const restore = useCancelAccountDeletionMutation();
  if (!deletion) {
    return null;
  }
  return (
    <DetailSection
      id="account-deletion"
      title="Yêu cầu xoá tài khoản"
      extra={
        <StatusChip tone={deletion.status === "PURGED" ? "danger" : "food"}>
          {accountDeletionLabel(deletion)}
        </StatusChip>
      }
    >
      <div data-testid="account-deletion-card" className="space-y-3">
        <p className="text-sm text-muted">{accountDeletionSummary(deletion)}</p>
        {canRestoreAccount(deletion) ? (
          <button
            type="button"
            onClick={() => setOpen(true)}
            className={`h-9 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink hover:bg-canvas ${focusRing}`}
          >
            Khôi phục tài khoản
          </button>
        ) : null}
      </div>
      <ReasonDialog
        open={open}
        title="Khôi phục tài khoản"
        description={`Huỷ yêu cầu xoá của ${name}. Người dùng đăng nhập lại được ngay; quán (nếu có) vẫn tạm ngưng cho tới khi chủ quán mở lại.`}
        confirmLabel="Khôi phục"
        testId="account-restore-dialog"
        onClose={() => setOpen(false)}
        onSubmit={async (reason) => {
          await restore.mutateAsync({ id: userId, reason });
          toast.success(`Đã khôi phục tài khoản ${name}.`);
        }}
      />
    </DetailSection>
  );
}
