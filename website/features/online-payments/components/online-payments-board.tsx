"use client";

import { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { AdminBreadcrumb, focusRing, PreviewButton, StatusChip, vnd } from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminFilterField,
  AdminFilterToolbar,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import { SearchSelect } from "@/components/ui/search-select";
import { toast } from "@/components/ui/toast";
import {
  usePaymentIntentQuery,
  usePaymentIntentsQuery,
  useReconcilePaymentIntentsMutation,
  useRefundPaymentIntentMutation,
} from "@/features/online-payments/hooks";
import {
  entityLabel,
  INTENT_STATUS_LABELS,
  intentStatusTone,
  parseRefundAmount,
  PROVIDER_LABELS,
  REFUND_STATUS_LABELS,
  refundableOf,
} from "@/features/online-payments/mappers";
import {
  INTENT_PROVIDERS,
  INTENT_STATUSES,
  type IntentEntityType,
  type IntentProvider,
  type IntentStatus,
  type OpsPaymentIntentDetail,
} from "@/features/online-payments/types";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";

const COLUMNS = ["Mã giao dịch", "Dịch vụ", "Cổng", "Số tiền", "Đã hoàn", "Trạng thái", "Cập nhật"] as const;

const dateTime = (iso: string | null) => (iso ? formatOpsDateTime(iso) : "—");

export function OnlinePaymentsBoard() {
  const [status, setStatus] = useState<IntentStatus | null>(null);
  const [provider, setProvider] = useState<IntentProvider | null>(null);
  const [entityType, setEntityType] = useState<IntentEntityType | null>(null);
  const [q, setQ] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const filter = { status, provider, entityType, q, limit: 100 };
  const { data, isPending, isError, error, refetch } = usePaymentIntentsQuery(filter);
  const reconcile = useReconcilePaymentIntentsMutation();
  const forbidden = isError && isForbiddenError(error);
  const items = data ?? [];
  const activeId = selectedId ?? items[0]?.id ?? null;

  const reset = () => {
    setStatus(null);
    setProvider(null);
    setEntityType(null);
    setQ("");
  };

  const runReconcile = async () => {
    try {
      const s = await reconcile.mutateAsync();
      toast.success(
        `Đối soát xong: kiểm ${s.checked}, thu ${s.captured}, lỗi ${s.failed}, hết hạn ${s.expired}, chờ ${s.pending}.`,
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Không thể đối soát.");
    }
  };

  return (
    <div className="space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài chính", href: "/transactions" },
          { label: "Thanh toán online" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Thanh toán online</h1>
          <p className="mt-1 text-sm text-muted">
            Giao dịch qua MoMo, ZaloPay, VNPay… Hoàn một phần nhiều lần được, tổng không vượt số đã thu.
            Đối soát hỏi trạng thái trực tiếp từ cổng cho giao dịch đang chờ.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void runReconcile()}
          disabled={reconcile.isPending}
          className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-semibold text-ink disabled:opacity-60 ${focusRing}`}
        >
          <OpsIcon name="refresh" className="size-4" />
          {reconcile.isPending ? "Đang đối soát…" : "Đối soát ngay"}
        </button>
      </div>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={INTENT_STATUSES.map((s) => ({ value: s, label: INTENT_STATUS_LABELS[s] }))}
              placeholder="Tất cả trạng thái"
              onChange={(v) => setStatus((v as IntentStatus | null) ?? null)}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Cổng thanh toán"
              icon="wallet"
              value={provider}
              options={INTENT_PROVIDERS.map((p) => ({ value: p, label: PROVIDER_LABELS[p] ?? p }))}
              placeholder="Tất cả cổng"
              onChange={(v) => setProvider((v as IntentProvider | null) ?? null)}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Dịch vụ"
              icon="sliders"
              value={entityType}
              options={[
                { value: "RIDE", label: "Chuyến xe" },
                { value: "FOOD_ORDER", label: "Đơn đồ ăn" },
              ]}
              placeholder="Tất cả dịch vụ"
              onChange={(v) => setEntityType((v as IntentEntityType | null) ?? null)}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label htmlFor="intent-query" className="text-xs font-medium text-muted">
              Tìm theo mã
            </label>
            <input
              id="intent-query"
              type="search"
              autoComplete="off"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="ID giao dịch, ID chuyến/đơn hoặc mã cổng (orderId)"
              className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
            />
          </AdminFilterField>
          <div className="flex shrink-0 items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton onClick={reset} />
          </div>
        </AdminFilterToolbar>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem thanh toán online"
          description="Cần quyền refunds.read để xem và refunds.write để hoàn tiền."
        />
      ) : isError ? (
        <AdminListErrorBanner message="Không thể tải giao dịch online." onRetry={() => void refetch()} />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="receipt"
          title="Chưa có giao dịch online phù hợp"
          description="Thử đổi bộ lọc. Khi chưa bật cổng nào, hệ thống chỉ dùng tiền mặt."
          action={<AdminResetFilterButton onClick={reset} label="Xóa bộ lọc" />}
        />
      ) : (
        <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(20rem,24rem)]">
          <AdminTableContainer>
            <AdminTable minWidth="min-w-[760px]" ariaBusy={isPending}>
              <AdminTableHeader>
                <AdminTableRow>
                  {COLUMNS.map((c) => (
                    <AdminTableHead key={c} align={c === "Số tiền" || c === "Đã hoàn" ? "right" : "left"}>
                      {c}
                    </AdminTableHead>
                  ))}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer columns={COLUMNS.length} rows={6} />
                ) : (
                  items.map((item) => (
                    <AdminTableRow
                      key={item.id}
                      onClick={() => setSelectedId(item.id)}
                      className={`cursor-pointer ${item.id === activeId ? "bg-brand/5 ring-1 ring-inset ring-brand/30" : ""}`}
                    >
                      <AdminTableCell className="font-mono text-xs font-semibold text-brand">
                        {item.id.slice(0, 8)}
                      </AdminTableCell>
                      <AdminTableCell>{entityLabel(item)}</AdminTableCell>
                      <AdminTableCell>{PROVIDER_LABELS[item.provider] ?? item.provider}</AdminTableCell>
                      <AdminTableCell align="right" className="font-semibold tabular-nums">
                        {vnd(item.amountVnd)}
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums text-muted">
                        {item.refundedVnd > 0 ? vnd(item.refundedVnd) : "—"}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={intentStatusTone(item.status)}>{INTENT_STATUS_LABELS[item.status]}</StatusChip>
                      </AdminTableCell>
                      <AdminTableCell className="text-muted">{dateTime(item.updatedAt)}</AdminTableCell>
                    </AdminTableRow>
                  ))
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          {activeId ? <IntentDetailPanel id={activeId} /> : null}
        </div>
      )}
    </div>
  );
}

function IntentDetailPanel({ id }: { id: string }) {
  const { data, isPending, isError, refetch } = usePaymentIntentQuery(id);
  if (isPending) {
    return <aside className="rounded-2xl border border-border bg-white p-4 text-sm text-muted shadow-sm">Đang tải…</aside>;
  }
  if (isError || !data) {
    return <AdminListErrorBanner message="Không thể tải chi tiết giao dịch." onRetry={() => void refetch()} />;
  }
  return <IntentDetail key={`${data.id}:${data.refundedVnd}`} intent={data} />;
}

function IntentDetail({ intent }: { intent: OpsPaymentIntentDetail }) {
  const refundable = intent.refundableVnd ?? refundableOf(intent);
  const [amount, setAmount] = useState(refundable > 0 ? String(refundable) : "");
  const [confirming, setConfirming] = useState<number | null>(null);
  const [amountError, setAmountError] = useState<string | null>(null);
  // One key per confirmed refund; reused if the same confirmation is retried.
  const [refundKey, setRefundKey] = useState<string>("");
  const mutation = useRefundPaymentIntentMutation();

  const rows: [string, string][] = [
    ["Dịch vụ", `${entityLabel(intent)} · ${intent.entityId}`],
    ["Phương thức", intent.methodCode ?? "—"],
    ["Mã cổng (orderId)", intent.providerRef ?? "—"],
    ["Mã giao dịch cổng", intent.providerTransId ?? "—"],
    ["Đã thu", vnd(intent.amountVnd)],
    ["Đã hoàn", vnd(intent.refundedVnd)],
    ["Còn hoàn được", vnd(refundable)],
    ["Đã quyết toán cho tài xế", intent.settledAt ? dateTime(intent.settledAt) : "Chưa"],
    ["Đối soát gần nhất", `${dateTime(intent.lastReconciledAt)} (${intent.reconcileAttempts} lần)`],
    ["Tạo lúc", dateTime(intent.createdAt)],
  ];

  const startRefund = () => {
    const parsed = parseRefundAmount(amount, refundable);
    if (!parsed.ok) {
      setAmountError(parsed.message);
      return;
    }
    setAmountError(null);
    setRefundKey(crypto.randomUUID());
    setConfirming(parsed.amountVnd);
  };

  return (
    <aside aria-label="Chi tiết giao dịch online" className="min-w-0 space-y-4">
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-xs font-semibold text-muted">{PROVIDER_LABELS[intent.provider] ?? intent.provider}</p>
            <p className="mt-1 break-all font-mono text-sm font-bold text-ink">{intent.id}</p>
          </div>
          <StatusChip tone={intentStatusTone(intent.status)}>{INTENT_STATUS_LABELS[intent.status]}</StatusChip>
        </div>
        {intent.failureReason ? (
          <p className="mt-3 rounded-xl border border-danger/30 bg-danger/5 p-2 text-xs text-danger">{intent.failureReason}</p>
        ) : null}
        <dl className="mt-4 space-y-2 text-sm">
          {rows.map(([k, v]) => (
            <div key={k} className="flex items-baseline justify-between gap-3">
              <dt className="shrink-0 text-muted">{k}</dt>
              <dd className="min-w-0 break-all text-right font-medium text-ink">{v}</dd>
            </div>
          ))}
        </dl>

        {refundable > 0 ? (
          <div className="mt-4 border-t border-border pt-3">
            <label htmlFor="refund-amount" className="text-xs font-medium text-muted">
              Số tiền hoàn (VND) — có thể hoàn một phần
            </label>
            <div className="mt-1.5 flex gap-2">
              <input
                id="refund-amount"
                inputMode="numeric"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className={`h-10 min-w-0 flex-1 rounded-xl border border-border bg-white px-3 text-sm tabular-nums text-ink ${focusRing}`}
              />
              <button
                type="button"
                onClick={startRefund}
                className={`rounded-xl bg-danger px-3 text-sm font-semibold text-white ${focusRing}`}
              >
                Hoàn tiền
              </button>
            </div>
            {amountError ? <p className="mt-1 text-xs text-danger">{amountError}</p> : null}
          </div>
        ) : null}
      </section>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <h2 className="text-sm font-semibold text-ink">Lịch sử hoàn tiền</h2>
        {intent.refunds.length === 0 ? (
          <p className="mt-2 text-sm text-muted">Chưa có lần hoàn nào.</p>
        ) : (
          <ul className="mt-2 space-y-2">
            {intent.refunds.map((r) => (
              <li key={r.id} className="rounded-xl border border-border p-2 text-xs">
                <div className="flex items-center justify-between gap-2">
                  <span className="font-semibold tabular-nums text-ink">{vnd(r.amountVnd)}</span>
                  <StatusChip tone={r.status === "SUCCEEDED" ? "success" : r.status === "REJECTED" ? "danger" : "delivery"}>
                    {REFUND_STATUS_LABELS[r.status]}
                  </StatusChip>
                </div>
                <p className="mt-1 text-muted">{r.reason}</p>
                <p className="mt-1 text-muted">
                  {dateTime(r.createdAt)}
                  {r.afterSettlement ? " · sau quyết toán (DealGo chịu)" : ""}
                  {r.providerRefundRef ? ` · ${r.providerRefundRef}` : ""}
                </p>
              </li>
            ))}
          </ul>
        )}
      </section>

      {confirming !== null ? (
        <OpsInterveneDialog
          open
          labels={{
            title: `Hoàn ${vnd(confirming)}`,
            confirm: "Xác nhận hoàn tiền",
            hint: "Gửi lệnh hoàn qua cổng thanh toán. Lý do (3–200 ký tự) được ghi vào nhật ký.",
            success: "Đã gửi lệnh hoàn tiền.",
          }}
          entityLabel={intent.providerRef ?? intent.id}
          pending={mutation.isPending}
          onClose={() => setConfirming(null)}
          onConfirm={async (reason) => {
            await mutation.mutateAsync({
              id: intent.id,
              amountVnd: confirming,
              reason: reason.slice(0, 200),
              idempotencyKey: refundKey || crypto.randomUUID(),
            });
          }}
        />
      ) : null}
    </aside>
  );
}
