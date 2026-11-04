"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

import {
  AdminBreadcrumb,
  ExportCsvButton,
  KpiCard,
  PreviewButton,
  StatusChip,
  focusRing,
  formatCompactVnd,
  vnd,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminFilterField,
  AdminFilterToolbar,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import { SearchSelect } from "@/components/ui/search-select";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import { DriverCreditRefundDialog } from "@/features/driver-credit/components/driver-credit-refund-dialog";
import {
  useDriverCreditSummaryQuery,
  useDriverTopUpsQuery,
  useReconcileDriverTopUpMutation,
  useReconcilePendingDriverTopUpsMutation,
  useRefundDriverTopUpMutation,
} from "@/features/driver-credit/hooks";
import {
  canReconcile,
  canRefund,
  consumedRatio,
  driverDisplayName,
  providerLabel,
  topUpMemo,
  topUpStatusLabel,
  topUpStatusOptions,
  topUpStatusTone,
} from "@/features/driver-credit/mappers";
import type { DriverTopUp } from "@/features/driver-credit/types";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";

const TABLE_COLUMNS = [
  { id: "driver", label: "Tài xế" },
  { id: "memo", label: "Mã nạp" },
  { id: "amount", label: "Số tiền", align: "right" },
  { id: "remaining", label: "Còn lại", align: "right" },
  { id: "provider", label: "Cổng" },
  { id: "status", label: "Trạng thái" },
  { id: "createdAt", label: "Tạo lúc" },
] as const;

const LIMIT = 100;

export function DriverCreditBoard() {
  const [status, setStatus] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [refundTarget, setRefundTarget] = useState<DriverTopUp | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const filter = useMemo(() => ({ status, limit: LIMIT }), [status]);

  const {
    data: topUps,
    isPending,
    isError,
    error: listError,
    refetch,
  } = useDriverTopUpsQuery(filter);
  const {
    data: summary,
    isError: summaryError,
    error: summaryQueryError,
  } = useDriverCreditSummaryQuery();

  const reconcileOne = useReconcileDriverTopUpMutation();
  const reconcileAll = useReconcilePendingDriverTopUpsMutation();
  const refund = useRefundDriverTopUpMutation();

  const forbidden = isError && isForbiddenError(listError);
  const rawItems = useMemo(() => topUps ?? [], [topUps]);
  const items = useMemo(() => {
    const needle = searchQuery.trim().toLowerCase();
    if (!needle) {
      return rawItems;
    }
    return rawItems.filter((item) => {
      const haystack = [
        item.driverName ?? "",
        item.driverPhone ?? "",
        topUpMemo(item),
        String(item.orderCode),
        item.providerRef ?? "",
        item.providerTransId ?? "",
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(needle);
    });
  }, [rawItems, searchQuery]);

  const selected =
    items.find((item) => item.id === selectedId) ?? items[0] ?? null;

  const errorMessage = listError
    ? listError instanceof Error
      ? listError.message
      : "Không thể tải danh sách nạp tiền."
    : null;
  const summaryUnavailable = summaryError;

  const kpis = [
    {
      label: "Lệnh chờ ghi có",
      value: summary?.pendingCount ?? 0,
      note: summary
        ? `Tổng ${vnd(summary.pendingVnd)}`
        : "Chưa tải được số liệu",
      tone: "food" as const,
      icon: "clock" as const,
    },
    {
      label: "Đã ghi có hôm nay",
      value: formatCompactVnd(summary?.paidTodayVnd ?? 0),
      note: "Tiền tài xế nạp trong ngày (giờ VN)",
      tone: "success" as const,
      icon: "check" as const,
    },
    {
      label: "Đã hoàn cho tài xế",
      value: formatCompactVnd(summary?.refundedVnd ?? 0),
      note: "Chuyển khoản thủ công đã ghi nhận",
      tone: "delivery" as const,
      icon: "undo" as const,
    },
    {
      label: "Tạm ứng còn lại",
      value: formatCompactVnd(summary?.outstandingCreditVnd ?? 0),
      note: "Chưa cấn trừ hết phí nền tảng",
      tone: "brand" as const,
      icon: "wallet" as const,
    },
  ];

  const resetFilters = () => {
    setStatus(null);
    setSearchQuery("");
  };

  const runReconcileAll = async () => {
    setActionError(null);
    setNotice(null);
    try {
      const result = await reconcileAll.mutateAsync();
      setNotice(
        `Đã kiểm tra ${result.checked} lệnh: ghi có ${result.captured}, đóng ${result.closed}.`,
      );
    } catch (err) {
      setActionError(
        err instanceof Error ? err.message : "Đối soát thất bại. Thử lại.",
      );
    }
  };

  const runReconcileOne = async (topUp: DriverTopUp) => {
    setActionError(null);
    setNotice(null);
    try {
      const updated = await reconcileOne.mutateAsync(topUp.id);
      setNotice(
        updated.status === "PAID"
          ? `Đã ghi có ${vnd(updated.amountVnd)} cho ${driverDisplayName(topUp)}.`
          : `Cổng thanh toán chưa xác nhận, lệnh vẫn ở trạng thái ${topUpStatusLabel(updated.status)}.`,
      );
    } catch (err) {
      setActionError(
        err instanceof Error ? err.message : "Đối soát thất bại. Thử lại.",
      );
    }
  };

  const copyMemo = async (topUp: DriverTopUp) => {
    try {
      await navigator.clipboard.writeText(topUpMemo(topUp));
      setCopiedId(topUp.id);
      setActionError(null);
    } catch {
      setActionError(
        "Trình duyệt không cho phép sao chép. Hãy chọn mã và copy tay.",
      );
    }
  };

  return (
    <div className="space-y-5">
      {errorMessage && !forbidden && rawItems.length > 0 ? (
        <AdminListErrorBanner
          message={errorMessage}
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài chính", href: "/transactions" },
          { label: "Tạm ứng tài xế" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Số dư tạm ứng tài xế
          </h1>
          <p className="mt-1 max-w-3xl text-sm text-muted">
            Tiền tài xế nạp trước để cấn trừ phí nền tảng — không rút, không
            chuyển nhượng. Ghi có chỉ đến từ callback có chữ ký hợp lệ của cổng
            thanh toán.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewButton
            onClick={() => {
              if (!reconcileAll.isPending) {
                void runReconcileAll();
              }
            }}
          >
            <OpsIcon name="refresh" className="size-4" />
            {reconcileAll.isPending ? "Đang đối soát…" : "Đối soát tất cả"}
          </PreviewButton>
          <ExportCsvButton
            filename="driver-credit-top-ups.csv"
            headers={[
              "Mã nạp",
              "Tài xế",
              "Số điện thoại",
              "Số tiền",
              "Còn lại",
              "Cổng",
              "Trạng thái",
              "Tạo lúc",
            ]}
            rows={items.map((item) => [
              topUpMemo(item),
              driverDisplayName(item),
              item.driverPhone ?? "",
              String(item.amountVnd),
              String(item.remainingVnd),
              providerLabel(item.provider),
              topUpStatusLabel(item.status),
              item.createdAt,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {kpis.map((kpi) => (
          <li key={kpi.label}>
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              note={
                summaryUnavailable && isForbiddenError(summaryQueryError)
                  ? "Thiếu quyền settlements.read"
                  : kpi.note
              }
              icon={kpi.icon}
              tone={kpi.tone}
            />
          </li>
        ))}
      </ul>

      {notice ? (
        <p
          role="status"
          className="rounded-2xl border border-success/30 bg-success/5 px-4 py-3 text-sm text-ink"
        >
          {notice}
        </p>
      ) : null}
      {actionError ? (
        <div
          role="alert"
          className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger"
        >
          <span>{actionError}</span>
          <button
            type="button"
            onClick={() => setActionError(null)}
            className={`text-xs font-semibold underline ${focusRing}`}
          >
            Đóng
          </button>
        </div>
      ) : null}

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[12rem]">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={topUpStatusOptions}
              placeholder="Tất cả trạng thái"
              onChange={(next) => setStatus(next)}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="driver-credit-query"
              className="text-xs font-medium text-muted"
            >
              Tìm lệnh nạp
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="driver-credit-query"
                type="search"
                autoComplete="off"
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                placeholder="Tên tài xế, số điện thoại, mã nạp, mã giao dịch..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton onClick={resetFilters} />
          </div>
        </AdminFilterToolbar>
        <p className="mt-3 text-xs text-muted">
          Hiển thị {items.length} / {rawItems.length} lệnh gần nhất (tối đa{" "}
          {LIMIT}).
        </p>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem tạm ứng tài xế"
          description="Tài khoản Ops hiện tại không được cấp quyền xem hoặc đối soát tiền nạp trước của tài xế."
        />
      ) : isError && rawItems.length === 0 ? (
        <AdminListErrorBanner
          message={errorMessage ?? "Lỗi tải danh sách tạm ứng tài xế."}
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="wallet"
          title="Không có lệnh nạp phù hợp"
          description="Thử đổi trạng thái hoặc từ khóa tìm kiếm."
          action={
            <AdminResetFilterButton onClick={resetFilters} label="Xóa bộ lọc" />
          }
        />
      ) : (
        <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(18rem,22rem)]">
          <div className="min-w-0 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 px-1">
              <h2 className="text-sm font-semibold text-ink">
                Danh sách lệnh nạp
              </h2>
              <p className="text-sm text-muted">Sắp xếp: Mới nhất</p>
            </div>
            <AdminTableContainer>
              <AdminTable minWidth="min-w-[860px]" ariaBusy={isPending}>
                <AdminTableHeader>
                  <AdminTableRow>
                    {TABLE_COLUMNS.map((col) => (
                      <AdminTableHead
                        key={col.id}
                        align={"align" in col ? col.align : "left"}
                      >
                        {col.label}
                      </AdminTableHead>
                    ))}
                  </AdminTableRow>
                </AdminTableHeader>
                <AdminTableBody>
                  {isPending ? (
                    <AdminTableBodyShimmer
                      columns={TABLE_COLUMNS.length}
                      rows={6}
                    />
                  ) : (
                    items.map((item) => {
                      const isSelected = item.id === selected?.id;
                      return (
                        <AdminTableRow
                          key={item.id}
                          onClick={() => setSelectedId(item.id)}
                          className={`cursor-pointer ${
                            isSelected
                              ? "bg-brand/5 ring-1 ring-inset ring-brand/30"
                              : ""
                          }`}
                        >
                          <AdminTableCell>
                            <span className="font-medium text-ink">
                              {driverDisplayName(item)}
                            </span>
                            <span className="block text-xs text-muted">
                              {item.driverPhone ?? item.driverId.slice(0, 8)}
                            </span>
                          </AdminTableCell>
                          <AdminTableCell className="font-mono text-xs text-brand">
                            {topUpMemo(item)}
                          </AdminTableCell>
                          <AdminTableCell
                            align="right"
                            className="font-semibold tabular-nums"
                          >
                            {vnd(item.amountVnd)}
                          </AdminTableCell>
                          <AdminTableCell
                            align="right"
                            className="tabular-nums text-muted"
                          >
                            {vnd(item.remainingVnd)}
                          </AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {providerLabel(item.provider)}
                          </AdminTableCell>
                          <AdminTableCell>
                            <StatusChip tone={topUpStatusTone(item.status)}>
                              {topUpStatusLabel(item.status)}
                            </StatusChip>
                          </AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {formatOpsDateTime(item.createdAt)}
                          </AdminTableCell>
                        </AdminTableRow>
                      );
                    })
                  )}
                </AdminTableBody>
              </AdminTable>
            </AdminTableContainer>
          </div>

          {selected ? (
            <aside aria-label="Chi tiết lệnh nạp" className="min-w-0 space-y-4">
              <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-xs font-semibold text-muted">Lệnh nạp</p>
                    <p className="mt-1 font-mono text-base font-bold text-ink">
                      {topUpMemo(selected)}
                    </p>
                  </div>
                  <StatusChip tone={topUpStatusTone(selected.status)}>
                    {topUpStatusLabel(selected.status)}
                  </StatusChip>
                </div>

                <div className="mt-4 rounded-xl border border-border bg-canvas/60 p-3">
                  <p className="text-xs text-muted">Số tiền nạp</p>
                  <p className="mt-0.5 text-xl font-bold text-ink tabular-nums">
                    {vnd(selected.amountVnd)}
                  </p>
                  <dl className="mt-2 grid grid-cols-2 gap-2 text-xs">
                    <div>
                      <dt className="text-muted">Đã cấn trừ</dt>
                      <dd className="font-semibold text-ink tabular-nums">
                        {vnd(selected.consumedVnd)}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-muted">Còn lại</dt>
                      <dd className="font-semibold text-ink tabular-nums">
                        {vnd(selected.remainingVnd)}
                      </dd>
                    </div>
                  </dl>
                  <div
                    className="mt-2 h-1.5 overflow-hidden rounded-full bg-border"
                    role="img"
                    aria-label={`Đã dùng ${Math.round(consumedRatio(selected) * 100)}% số tiền nạp`}
                  >
                    <div
                      className="h-full rounded-full bg-brand"
                      style={{ width: `${consumedRatio(selected) * 100}%` }}
                    />
                  </div>
                </div>

                <dl className="mt-4 space-y-3 text-sm">
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Tài xế</dt>
                    <dd className="text-right font-medium text-ink">
                      <Link
                        href={`/drivers/${selected.driverId}`}
                        className={`text-brand hover:underline ${focusRing}`}
                      >
                        {driverDisplayName(selected)}
                      </Link>
                      {selected.driverPhone ? (
                        <span className="block text-xs text-muted">
                          {selected.driverPhone}
                        </span>
                      ) : null}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Cổng thanh toán</dt>
                    <dd className="font-medium text-ink">
                      {providerLabel(selected.provider)}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Tạo lúc</dt>
                    <dd className="font-medium text-ink">
                      {formatOpsDateTime(selected.createdAt)}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Hết hạn</dt>
                    <dd className="font-medium text-ink">
                      {formatOpsDateTime(selected.expiresAt)}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Ghi có</dt>
                    <dd className="font-medium text-ink">
                      {formatOpsDateTime(selected.paidAt)}
                    </dd>
                  </div>
                  {selected.providerRef ? (
                    <div>
                      <dt className="text-muted">Mã tham chiếu cổng</dt>
                      <dd className="mt-1 break-all rounded-lg border border-border bg-canvas/60 px-2 py-1 font-mono text-xs text-ink">
                        {selected.providerRef}
                      </dd>
                    </div>
                  ) : null}
                  {selected.providerTransId ? (
                    <div>
                      <dt className="text-muted">Mã giao dịch cổng</dt>
                      <dd className="mt-1 break-all rounded-lg border border-border bg-canvas/60 px-2 py-1 font-mono text-xs text-ink">
                        {selected.providerTransId}
                      </dd>
                    </div>
                  ) : null}
                  {selected.failureReason ? (
                    <div>
                      <dt className="text-muted">Lỗi từ cổng</dt>
                      <dd className="mt-1 rounded-lg border border-danger/30 bg-danger/5 px-2 py-1 text-xs text-danger">
                        {selected.failureReason}
                      </dd>
                    </div>
                  ) : null}
                </dl>

                {selected.status === "REFUNDED" ? (
                  <div className="mt-4 rounded-xl border border-border bg-canvas/60 p-3 text-xs text-ink">
                    <p className="font-semibold">
                      Đã hoàn {vnd(selected.refundedVnd)}
                    </p>
                    <p className="mt-1 text-muted">
                      {formatOpsDateTime(selected.refundedAt)} · Mã CK:{" "}
                      <span className="font-mono">
                        {selected.refundBankRef ?? "—"}
                      </span>
                    </p>
                    {selected.refundReason ? (
                      <p className="mt-1 text-muted">
                        Lý do: {selected.refundReason}
                      </p>
                    ) : null}
                  </div>
                ) : null}

                <div className="mt-4 flex flex-col gap-2 border-t border-border pt-3">
                  {canReconcile(selected) ? (
                    <button
                      type="button"
                      disabled={reconcileOne.isPending}
                      onClick={() => void runReconcileOne(selected)}
                      className={`inline-flex h-10 items-center justify-center gap-1.5 rounded-xl bg-brand px-3 text-sm font-semibold text-white disabled:opacity-60 ${focusRing}`}
                    >
                      <OpsIcon name="refresh" className="size-4" />
                      {reconcileOne.isPending
                        ? "Đang đối soát…"
                        : "Đối soát với cổng"}
                    </button>
                  ) : null}
                  {canRefund(selected) ? (
                    <button
                      type="button"
                      onClick={() => setRefundTarget(selected)}
                      className={`inline-flex h-10 items-center justify-center gap-1.5 rounded-xl border border-danger/40 bg-white px-3 text-sm font-semibold text-danger hover:bg-danger/5 ${focusRing}`}
                    >
                      <OpsIcon name="undo" className="size-4" />
                      Hoàn tiền còn lại ({vnd(selected.remainingVnd)})
                    </button>
                  ) : null}
                  <button
                    type="button"
                    onClick={() => void copyMemo(selected)}
                    className={`inline-flex h-10 items-center justify-center gap-1.5 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink hover:bg-canvas ${focusRing}`}
                  >
                    <OpsIcon name="receipt" className="size-4" />
                    {copiedId === selected.id
                      ? "Đã sao chép mã nạp"
                      : "Sao chép mã nạp"}
                  </button>
                  {selected.checkoutUrl && selected.status === "PENDING" ? (
                    <Link
                      href={selected.checkoutUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className={`inline-flex h-10 items-center justify-center gap-1.5 rounded-xl border border-border bg-white px-3 text-sm font-medium text-brand hover:bg-canvas ${focusRing}`}
                    >
                      <OpsIcon name="arrowRight" className="size-4" />
                      Mở trang thanh toán
                    </Link>
                  ) : null}
                </div>
              </section>
            </aside>
          ) : null}
        </div>
      )}

      <DriverCreditRefundDialog
        open={refundTarget !== null}
        driverLabel={refundTarget ? driverDisplayName(refundTarget) : ""}
        refundableVnd={refundTarget?.remainingVnd ?? 0}
        onClose={() => setRefundTarget(null)}
        onSubmit={async (input) => {
          if (!refundTarget) {
            return;
          }
          await refund.mutateAsync({
            id: refundTarget.id,
            reason: input.reason,
            bankRef: input.bankRef,
          });
          setNotice(
            `Đã ghi nhận hoàn ${vnd(refundTarget.remainingVnd)} cho tài xế.`,
          );
        }}
      />
    </div>
  );
}
