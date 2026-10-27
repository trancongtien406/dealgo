"use client";

import { useState } from "react";
import { focusRing, StatusChip, vnd } from "@/components/ui/admin-list-ui";
import { toast } from "@/components/ui/toast";
import {
  useRecordStoreSettlementMutation,
  useStoreStatementQuery,
} from "@/features/stores/hooks";
import { checkOpsReason } from "@/lib/api/ops-reason-body";
import {
  checkStatementRange,
  defaultStatementRange,
} from "@/lib/merchant-statement";
import { formatOpsDateTime } from "@/lib/ops-time";

/**
 * (OPEN-018) What the store received in cash at pickup, the DealGo
 * commission it owes, and the payments Ops recorded (GrabFood / ShopeeFood merchant
 * statements). Days are Vietnam days.
 */
export function StoreStatementPanel({
  storeId,
  storeName,
}: {
  storeId: string;
  storeName: string;
}) {
  const [draft, setDraft] = useState(defaultStatementRange);
  const [range, setRange] = useState(defaultStatementRange);
  const [rangeError, setRangeError] = useState<string | null>(null);
  const statement = useStoreStatementQuery(storeId, range);
  const data = statement.data;
  const input = `h-9 rounded-xl border border-border bg-canvas px-3 text-sm text-ink ${focusRing}`;

  return (
    <div className="space-y-4" data-testid="store-statement">
      <form
        className="flex flex-wrap items-end gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          const checked = checkStatementRange(draft);
          if (!checked.ok) {
            setRangeError(checked.message);
            return;
          }
          setRangeError(null);
          setRange(checked.value);
        }}
      >
        <label className="text-sm text-muted">
          Từ ngày
          <input
            type="date"
            className={`${input} ml-2`}
            value={draft.from}
            onChange={(e) => setDraft((d) => ({ ...d, from: e.target.value }))}
          />
        </label>
        <label className="text-sm text-muted">
          Đến ngày
          <input
            type="date"
            className={`${input} ml-2`}
            value={draft.to}
            onChange={(e) => setDraft((d) => ({ ...d, to: e.target.value }))}
          />
        </label>
        <button
          type="submit"
          className={`h-9 rounded-xl border border-border px-3 text-sm font-semibold text-ink hover:bg-canvas ${focusRing}`}
        >
          Xem sao kê
        </button>
        {rangeError ? (
          <p role="alert" className="w-full text-sm text-danger">
            {rangeError}
          </p>
        ) : null}
      </form>

      {statement.isPending ? (
        <p className="text-sm text-muted">Đang tải sao kê…</p>
      ) : statement.isError ? (
        <p role="alert" className="text-sm text-danger">
          Không tải được sao kê.
        </p>
      ) : data ? (
        <>
          <dl
            className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm sm:grid-cols-3"
            data-testid="store-statement-totals"
          >
            <dt className="text-muted">Đơn đã giao</dt>
            <dd className="text-right text-ink sm:col-span-2">
              {data.totals.orderCount}
            </dd>
            <dt className="text-muted">Tiền món (trước voucher)</dt>
            <dd className="text-right text-ink sm:col-span-2">
              {vnd(data.totals.grossVnd)}
            </dd>
            <dt className="text-muted">Voucher quán tài trợ</dt>
            <dd className="text-right text-ink sm:col-span-2">
              {vnd(data.totals.merchantFundedVnd)}
            </dd>
            <dt className="text-muted">Quán nhận tiền mặt từ tài xế</dt>
            <dd className="text-right text-ink sm:col-span-2">
              {vnd(data.totals.cashReceivedVnd)}
            </dd>
            <dt className="text-muted">
              Hoa hồng DealGo (hiện {data.commissionPercentNow}%)
            </dt>
            <dd className="text-right text-ink sm:col-span-2">
              {vnd(data.totals.commissionVnd)}
            </dd>
            <dt className="text-muted">Quán giữ lại</dt>
            <dd className="text-right font-semibold text-ink sm:col-span-2">
              {vnd(data.totals.netVnd)}
            </dd>
            {data.settlementCycleDays > 0 ? (
              <>
                <dt className="text-muted">Chu kỳ đối soát</dt>
                <dd className="text-right text-ink sm:col-span-2">
                  {data.settlementCycleDays} ngày / lần
                </dd>
              </>
            ) : null}
            <dt className="text-muted">Hoa hồng chưa nộp</dt>
            <dd className="text-right sm:col-span-2">
              <StatusChip
                tone={data.unsettledCommissionVnd > 0 ? "danger" : "success"}
              >
                {vnd(data.unsettledCommissionVnd)}
              </StatusChip>
            </dd>
          </dl>

          {data.days.length > 0 ? (
            <table
              className="w-full text-sm"
              data-testid="store-statement-days"
            >
              <thead>
                <tr className="text-left text-muted">
                  <th className="py-1 font-medium">Ngày</th>
                  <th className="py-1 text-right font-medium">Đơn</th>
                  <th className="py-1 text-right font-medium">Tiền mặt nhận</th>
                  <th className="py-1 text-right font-medium">Hoa hồng</th>
                </tr>
              </thead>
              <tbody>
                {data.days.map((day) => (
                  <tr key={day.date} className="border-t border-border">
                    <td className="py-1">{day.date}</td>
                    <td className="py-1 text-right">{day.orderCount}</td>
                    <td className="py-1 text-right">
                      {vnd(day.cashReceivedVnd)}
                    </td>
                    <td className="py-1 text-right">
                      {vnd(day.commissionVnd)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="text-sm text-muted">
              Không có đơn đã giao trong khoảng này.
            </p>
          )}

          <div className="space-y-1">
            <p className="text-sm font-medium text-ink">
              Các lần quán đã nộp hoa hồng
            </p>
            {data.settlements.length === 0 ? (
              <p className="text-sm text-muted">
                Chưa có lần nộp nào trong khoảng này.
              </p>
            ) : (
              <ul
                className="divide-y divide-border text-sm"
                data-testid="store-settlements"
              >
                {data.settlements.map((row) => (
                  <li
                    key={row.id}
                    className="flex flex-wrap justify-between gap-2 py-1"
                  >
                    <span>
                      {row.periodStart} → {row.periodEnd} · {row.orderCount} đơn
                      {row.note ? ` · ${row.note}` : ""}
                    </span>
                    <span className="text-muted">
                      {vnd(row.commissionVnd)} · ghi lúc{" "}
                      {formatOpsDateTime(row.createdAt)}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </>
      ) : null}

      <StoreSettlementForm storeId={storeId} storeName={storeName} />
    </div>
  );
}

/** Ops records that the store paid DealGo the commission for closed ICT days (audited). */
function StoreSettlementForm({
  storeId,
  storeName,
}: {
  storeId: string;
  storeName: string;
}) {
  const record = useRecordStoreSettlementMutation(storeId);
  const [period, setPeriod] = useState(defaultStatementRange);
  const [reason, setReason] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const input = `h-9 rounded-xl border border-border bg-canvas px-3 text-sm text-ink ${focusRing}`;
  return (
    <form
      className="space-y-2 border-t border-border pt-3"
      data-testid="store-settlement-form"
      onSubmit={async (event) => {
        event.preventDefault();
        const checked = checkStatementRange(period, { closedOnly: true });
        const why = checkOpsReason({ reason });
        if (!checked.ok || !why.ok) {
          setError(!checked.ok ? checked.message : why.ok ? null : why.message);
          return;
        }
        setError(null);
        try {
          await record.mutateAsync({
            ...checked.value,
            reason: why.value.reason,
            ...(note.trim() ? { note: note.trim() } : {}),
          });
          toast.success(
            `Đã ghi nhận ${storeName} nộp hoa hồng ${checked.value.from} → ${checked.value.to}.`,
          );
          setReason("");
          setNote("");
        } catch (e) {
          setError(e instanceof Error ? e.message : "Không ghi nhận được.");
        }
      }}
    >
      <p className="text-sm font-medium text-ink">
        Ghi nhận quán đã nộp hoa hồng
      </p>
      <p className="text-xs text-muted">
        Chỉ chốt các ngày đã qua; số tiền do hệ thống tính lại, không trùng kỳ
        đã ghi.
      </p>
      <div className="flex flex-wrap gap-2">
        <input
          type="date"
          aria-label="Từ ngày"
          className={input}
          value={period.from}
          onChange={(e) => setPeriod((p) => ({ ...p, from: e.target.value }))}
        />
        <input
          type="date"
          aria-label="Đến ngày"
          className={input}
          value={period.to}
          onChange={(e) => setPeriod((p) => ({ ...p, to: e.target.value }))}
        />
        <input
          aria-label="Lý do"
          placeholder="Lý do (bắt buộc)"
          className={`${input} min-w-48 flex-1`}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
        <input
          aria-label="Ghi chú"
          placeholder="Ghi chú (mã chuyển khoản…)"
          className={`${input} min-w-40`}
          value={note}
          maxLength={500}
          onChange={(e) => setNote(e.target.value)}
        />
        <button
          type="submit"
          disabled={record.isPending}
          className={`h-9 rounded-xl bg-brand px-3 text-sm font-semibold text-white hover:bg-brand/90 disabled:opacity-60 ${focusRing}`}
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
