"use client";

import { useState } from "react";
import { focusRing, StatusChip, vnd } from "@/components/ui/admin-list-ui";
import { DetailSection } from "@/components/ui/admin-detail-ui";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { toast } from "@/components/ui/toast";
import {
  useDriverFeeBalanceQuery,
  useSettleDriverFeesMutation,
} from "@/features/account-deletion/hooks";
import { formatOpsDate } from "@/lib/ops-time";

/**
 * Platform fee the driver owes on cash (COD) jobs since the last settlement. Ops marks it as
 * collected (audited); an unsettled amount blocks S027 account deletion.
 */
export function DriverFeeCard({ driverId, name }: { driverId: string; name: string }) {
  const [open, setOpen] = useState(false);
  const balance = useDriverFeeBalanceQuery(driverId);
  const settle = useSettleDriverFeesMutation();
  const amount = balance.data?.amountVnd ?? 0;
  return (
    <DetailSection
      id="driver-fee"
      title="Phí nền tảng chưa đối soát"
      extra={
        <StatusChip tone={amount > 0 ? "food" : "success"}>
          {amount > 0 ? "Còn nợ" : "Đã đối soát"}
        </StatusChip>
      }
    >
      <div data-testid="driver-fee-card" className="space-y-2">
        <p className="text-2xl font-semibold text-ink">
          {balance.isPending ? "…" : vnd(amount)}
        </p>
        <p className="text-sm text-muted">
          {balance.isError
            ? "Không tải được số dư phí."
            : balance.data?.settledThrough
              ? `Lần đối soát gần nhất: ${formatOpsDate(balance.data.settledThrough)}`
              : "Chưa có lần đối soát nào."}
        </p>
        {amount > 0 ? (
          <button
            type="button"
            onClick={() => setOpen(true)}
            className={`h-9 rounded-xl bg-brand px-3 text-sm font-semibold text-white hover:bg-brand/90 ${focusRing}`}
          >
            Xác nhận đã thu
          </button>
        ) : null}
      </div>
      <ReasonDialog
        open={open}
        title="Xác nhận đã thu phí nền tảng"
        description={`${name} đã nộp ${vnd(amount)} phí nền tảng của các cuốc tiền mặt. Thao tác ghi nhật ký kiểm toán.`}
        confirmLabel="Xác nhận"
        testId="driver-fee-dialog"
        onClose={() => setOpen(false)}
        onSubmit={async (reason) => {
          const done = await settle.mutateAsync({ id: driverId, reason });
          toast.success(`Đã ghi nhận ${vnd(done.amountVnd)} từ ${name}.`);
        }}
      />
    </DetailSection>
  );
}
