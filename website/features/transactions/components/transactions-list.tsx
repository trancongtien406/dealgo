"use client";
import { useState } from "react";

import Link from "next/link";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  focusRing,
  formatCount,
  KpiCard,
  ListPager,
  StatusChip,
  vnd,
  ExportCsvButton,
} from "@/components/ui/admin-list-ui";
import { SearchSelect } from "@/components/ui/search-select";
import {
  paymentMethodOptions,
  serviceScopeOptions,
} from "@/lib/admin-filter-options";
import {
  DateRangePicker,
  type DateRangeValue,
} from "@/components/ui/date-picker";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import {
  AdminEmptyState,
  AdminFilterField,
  AdminFilterToolbar,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import { isForbiddenError } from "@/lib/api/errors";
import {
  useTransactionListFilters,
  useTransactionsQuery,
} from "@/features/transactions/hooks";
import {
  txServiceLabel,
  txServiceMark,
  txStatusFilterOptions,
  txStatusLabel,
  txStatusTone,
} from "@/features/transactions/mappers";
import { filteredStatusKpi } from "@/lib/admin-kpi";
import { coercePageSize, type PageSize } from "@/lib/admin-pagination";

import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import {
  TRANSACTION_COLUMN_COUNT,
  TRANSACTION_TABLE_COLUMNS,
} from "@/features/transactions/constants";

export function TransactionsList() {
  const [filters, setFilters] = useTransactionListFilters();
  const [dateRange, setDateRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });
  const { data, isPending, isError, error, refetch } = useTransactionsQuery();
  const items = data?.items ?? [];
  const total = data?.total ?? items.length;
  const forbidden = isError && isForbiddenError(error);

  const collectedKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: ["COLLECTED", "COD_CONFIRMED"],
    total,
    pageCount: items.filter(
      (row) => row.status === "COLLECTED" || row.status === "COD_CONFIRMED",
    ).length,
  });
  const pendingKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: ["COD_PENDING", "PROCESSING"],
    total,
    pageCount: items.filter(
      (row) => row.status === "COD_PENDING" || row.status === "PROCESSING",
    ).length,
  });
  const failedKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "FAILED",
    total,
    pageCount: items.filter((row) => row.status === "FAILED").length,
  });

  const resetFilters = () => {
    setDateRange({ from: null, to: null });
    void setFilters({
      q: "",
      status: "ALL",
      service: "ALL",
      payment: "ALL",
      page: 1,
    });
  };

  const onPageSizeChange = (size: PageSize) => {
    void setFilters({ limit: size, page: 1 });
  };

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách giao dịch mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài chính", href: "/transactions" },
          { label: "Danh sách giao dịch" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách giao dịch
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi khoản thu, COD, trạng thái thanh toán và đối soát trên một
            màn hình.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter defaultPreset="today" />
          <ExportCsvButton
            filename="transactions.csv"
            headers={["Mã", "Trạng thái"]}
            rows={items.map((row) => [row.code, row.status])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <li>
          <KpiCard
            label="Tổng giao dịch"
            value={total}
            note="theo bộ lọc"
            icon="receipt"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đã thu / COD xác nhận"
            value={collectedKpi.value}
            note={collectedKpi.note}
            noteTone="success"
            icon="check"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Chờ xác nhận / xử lý"
            value={pendingKpi.value}
            note={pendingKpi.note}
            noteTone="food"
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Thất bại"
            value={failedKpi.value}
            note={failedKpi.note}
            noteTone="danger"
            icon="alert"
            tone="danger"
          />
        </li>
        <li>
          <KpiCard
            label="Hoàn tiền"
            value="—"
            note="Xem /refunds"
            noteTone="delivery"
            icon="undo"
            tone="delivery"
          />
        </li>
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField grow>
            <label
              htmlFor="transactions-query"
              className="text-xs font-medium text-muted"
            >
              Tìm kiếm
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="transactions-query"
                type="search"
                autoComplete="off"
                placeholder="Mã GD, đơn hàng, khách hàng..."
                value={filters.q}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Dịch vụ"
              value={filters.service === "ALL" ? null : filters.service}
              options={serviceScopeOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả dịch vụ"
              onChange={(next) => {
                void setFilters({ service: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Thanh toán"
              value={filters.payment === "ALL" ? null : filters.payment}
              options={paymentMethodOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả phương thức"
              onChange={(next) => {
                void setFilters({ payment: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={filters.status === "ALL" ? null : filters.status}
              options={txStatusFilterOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả trạng thái"
              onChange={(next) => {
                void setFilters({
                  status: (next ?? "ALL") as typeof filters.status,
                  page: 1,
                });
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[12rem]">
            <DateRangePicker
              label="Thời gian"
              value={dateRange}
              onChange={setDateRange}
            />
          </AdminFilterField>
          <div className="flex shrink-0 items-end">
            <button
              type="button"
              onClick={resetFilters}
              className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink ${focusRing}`}
            >
              Đặt lại
            </button>
          </div>
        </AdminFilterToolbar>
      </section>
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập sổ giao dịch"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc đối soát các giao dịch tài chính."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách giao dịch."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="receipt"
          title="Không có giao dịch phù hợp"
          description="Không tìm thấy giao dịch nào phù hợp với bộ lọc hiện tại. Thử đổi bộ lọc."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <h2 className="flex flex-wrap items-center gap-2 text-base font-semibold text-ink">
              Sổ giao dịch
              <span className="rounded-full bg-brand/10 px-2.5 py-1 text-xs font-semibold text-brand">
                Toàn hệ thống
              </span>
            </h2>
            <div className="flex flex-wrap items-center gap-3">
              <p className="text-sm text-muted">
                Cập nhật theo trạng thái backend
              </p>
              <Link
                href="/settlements"
                className={`inline-flex items-center gap-1 text-sm font-medium text-brand ${focusRing}`}
              >
                Đối soát
                <OpsIcon name="arrowRight" className="size-3.5" />
              </Link>
              <Link
                href="/refunds"
                className={`inline-flex items-center gap-1 text-sm font-medium text-brand ${focusRing}`}
              >
                Hoàn tiền
                <OpsIcon name="arrowRight" className="size-3.5" />
              </Link>
            </div>
          </div>
          <AdminTableContainer minWidth="min-w-[1100px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách giao dịch">
              <AdminTableHeader>
                <AdminTableRow>
                  {TRANSACTION_TABLE_COLUMNS.map((col) => (
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
                  <AdminTableBodyShimmer columns={TRANSACTION_COLUMN_COUNT} />
                ) : (
                  items.map((row) => {
                    const mark = txServiceMark(row.service);
                    return (
                      <AdminTableRow key={row.code}>
                        <AdminTableCell className="font-semibold text-brand">
                          {row.code}
                        </AdminTableCell>
                        <AdminTableCell>{row.time}</AdminTableCell>
                        <AdminTableCell>
                          <span className="inline-flex items-center gap-2 text-ink">
                            <span
                              className={`grid size-7 place-items-center rounded-lg ${mark.className}`}
                            >
                              <OpsIcon name={mark.icon} className="size-3.5" />
                            </span>
                            {txServiceLabel(row.service)}
                          </span>
                        </AdminTableCell>
                        <AdminTableCell className="font-medium text-brand">
                          {row.orderCode}
                        </AdminTableCell>
                        <AdminTableCell>{row.customer}</AdminTableCell>
                        <AdminTableCell>{row.method}</AdminTableCell>
                        <AdminTableCell
                          align="right"
                          className="font-semibold tabular-nums"
                        >
                          {vnd(row.amount)}
                        </AdminTableCell>
                        <AdminTableCell>
                          <StatusChip tone={txStatusTone(row.status)}>
                            {txStatusLabel(row.status)}
                          </StatusChip>
                        </AdminTableCell>
                        <AdminTableCell>{row.area}</AdminTableCell>
                        <AdminTableCell></AdminTableCell>
                      </AdminTableRow>
                    );
                  })
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager
            summary={`Hiển thị ${items.length} / ${formatCount(total)} giao dịch`}
            label="Phân trang giao dịch"
            page={filters.page}
            onPageChange={(next) => void setFilters({ page: next })}
            lastPage={Math.max(
              1,
              Math.ceil(total / Math.max(1, filters.limit)),
            )}
            pageSize={coercePageSize(filters.limit)}
            onPageSizeChange={onPageSizeChange}
          />
        </div>
      )}
      <p className="text-xs leading-5 text-muted">
        COD là khoản thu hộ, không đồng nghĩa tiền đã về ví hoặc tài khoản ngân
        hàng của DealGo.
      </p>
    </div>
  );
}
