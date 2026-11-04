"use client";

import { useState } from "react";
import { focusRing, StatusChip, vnd } from "@/components/ui/admin-list-ui";
import { DetailSection } from "@/components/ui/admin-detail-ui";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { toast } from "@/components/ui/toast";
import {
  useDriverBalanceQuery,
  useDriverPaymentMutation,
  useSettleDriverFeesMutation,
} from "@/features/account-deletion/hooks";
import {
  adjustmentKindLabel,
  checkDriverPayment,
  debtUsagePercent,
  type DriverPaymentDirection,
} from "@/lib/driver-balance";
import { checkOpsReason } from "@/lib/api/ops-reason-body";
import { formatOpsDate } from "@/lib/ops-time";

/**
 * What the driver owes DealGo since the last settlement = platform fees on cash
 * jobs + signed adjustments (cancel/no-show fees collected or paid out, food voucher
 * reimbursements). Above DRIVER_DEBT_LIMIT_VND the driver gets no new jobs. Ops marks it as
 * collected (audited); an unsettled amount blocks S027 account deletion.
 */
export function DriverFeeCard({ driverId, name }: { driverId: string; name: string }) {
  const [open, setOpen] = useState(false);
  const balance = useDriverBalanceQuery(driverId);
  const settle = useSettleDriverFeesMutation();
  const amount = balance.data?.amountVnd ?? 0;
  const data = balance.data;
  return (
    <DetailSection
      id="driver-fee"
      title="Phí nền tảng chưa đối soát"
      extra={
        <StatusChip
          tone={data?.blocked ? "danger" : amount > 0 ? "food" : "success"}
        >
          {data?.blocked
            ? "Vượt hạn mức – tạm khoá nhận cuốc"
            : amount > 0
              ? "Còn nợ"
              : "Đã đối soát"}
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
        {data ? (
          <dl
            className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm"
            data-testid="driver-balance-breakdown"
          >
            <dt className="text-muted">Phí nền tảng (cuốc tiền mặt)</dt>
            <dd className="text-right text-ink">{vnd(data.feesVnd)}</dd>
            <dt className="text-muted">Điều chỉnh (phí huỷ, voucher…)</dt>
            <dd className="text-right text-ink">{vnd(data.adjustmentsVnd)}</dd>
            <dt className="text-muted">Tạm ứng còn lại (cấn trừ)</dt>
            <dd className="text-right text-ink" data-testid="driver-credit-offset">
              {vnd(data.creditVnd)}
            </dd>
            <dt className="text-muted">Hạn mức nợ</dt>
            <dd className="text-right text-ink">
              {data.limitVnd > 0
                ? `${vnd(data.limitVnd)} (${debtUsagePercent(data)}%)`
                : "Tắt"}
            </dd>
            {data.cancelRate ? (
              <>
                <dt className="text-muted">
                  Tỉ lệ huỷ {data.cancelRate.windowDays} ngày
                </dt>
                <dd
                  className={`text-right ${data.cancelRate.warn ? "font-semibold text-danger" : "text-ink"}`}
                  data-testid="driver-cancel-rate"
                >
                  {data.cancelRate.percent}% ({data.cancelRate.cancelled}/
                  {data.cancelRate.cancelled + data.cancelRate.completed})
                  {data.cancelRate.warn
                    ? ` · vượt ngưỡng ${data.cancelRate.warnPercent}%`
                    : ""}
                </dd>
              </>
            ) : null}
          </dl>
        ) : null}
        {data && data.adjustments.length > 0 ? (
          <table className="w-full text-sm" data-testid="driver-balance-ledger">
            <thead>
              <tr className="text-left text-muted">
                <th className="py-1 font-medium">Thời điểm</th>
                <th className="py-1 font-medium">Loại</th>
                <th className="py-1 text-right font-medium">Số tiền</th>
              </tr>
            </thead>
            <tbody>
              {data.adjustments.map((row) => (
                <tr key={row.id} className="border-t border-border">
                  <td className="py-1">{formatOpsDate(row.occurredAt)}</td>
                  <td className="py-1">{adjustmentKindLabel(row.kind)}</td>
                  <td className="py-1 text-right">{vnd(row.amountVnd)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}
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
      <DriverPaymentForm driverId={driverId} name={name} />
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

/** Partial payment / top-up (driver → DealGo) or payout (DealGo → driver), audited. */
function DriverPaymentForm({ driverId, name }: { driverId: string; name: string }) {
  const pay = useDriverPaymentMutation();
  const [direction, setDirection] = useState<DriverPaymentDirection>("DRIVER_PAID");
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const input = `h-9 rounded-xl border border-border bg-canvas px-3 text-sm text-ink ${focusRing}`;
  return (
    <form
      className="mt-4 space-y-2 border-t border-border pt-3"
      data-testid="driver-payment-form"
      onSubmit={async (event) => {
        event.preventDefault();
        const checked = checkDriverPayment({ direction, amountVnd: amount.replace(/\D/g, "") });
        const why = checkOpsReason({ reason });
        if (!checked.ok || !why.ok) {
          setError(!checked.ok ? checked.message : why.ok ? null : why.message);
          return;
        }
        setError(null);
        try {
          await pay.mutateAsync({ id: driverId, ...checked.value, reason: why.value.reason });
          toast.success(`Đã ghi nhận ${vnd(checked.value.amountVnd)} cho ${name}.`);
          setAmount("");
          setReason("");
        } catch (e) {
          setError(e instanceof Error ? e.message : "Không ghi nhận được.");
        }
      }}
    >
      <p className="text-sm font-medium text-ink">Ghi nhận thanh toán từng phần</p>
      <div className="flex flex-wrap gap-2">
        <select
          aria-label="Chiều thanh toán"
          className={input}
          value={direction}
          onChange={(e) => setDirection(e.target.value as DriverPaymentDirection)}
        >
          <option value="DRIVER_PAID">Tài xế nộp / nạp trước</option>
          <option value="DEALGO_PAID">DealGo chi trả tài xế</option>
        </select>
        <input
          aria-label="Số tiền (₫)"
          inputMode="numeric"
          placeholder="Số tiền (₫)"
          className={`${input} w-36`}
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />
        <input
          aria-label="Lý do"
          placeholder="Lý do (bắt buộc)"
          className={`${input} min-w-48 flex-1`}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
        <button
          type="submit"
          disabled={pay.isPending}
          className={`h-9 rounded-xl border border-border px-3 text-sm font-semibold text-ink hover:bg-canvas disabled:opacity-60 ${focusRing}`}
        >
          Ghi nhận
        </button>
      </div>
      {error ? (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      ) : null}
    </form>
  );
}
