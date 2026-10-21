"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  ExportCsvButton,
  focusRing,
  KpiCard,
  ListPager,
  PreviewButton,
  StatusChip,
  vnd,
  type PageSize,
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
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import { type DateRangeValue } from "@/components/ui/date-picker";
import { SearchSelect } from "@/components/ui/search-select";
import { refundStatusOptions } from "@/lib/admin-filter-options";
import { filteredStatusKpi } from "@/lib/admin-kpi";
import { isDateWithinRange } from "@/lib/admin-date";
import { isForbiddenError } from "@/lib/api/errors";
import {
  refundStatusLabel,
  refundStatusTone,
  resolveRefundOrderRoute,
} from "@/features/refunds/mappers";
import { useRefundsQuery } from "@/features/refunds/hooks";
import {
  AdminTableContainer,
  AdminTable,
  AdminTableHeader,
  AdminTableHead,
  AdminTableBody,
  AdminTableRow,
  AdminTableCell,
} from "@/components/ui/admin-table";
import {
  REFUND_TABLE_COLUMNS,
  REFUND_COLUMN_COUNT,
} from "@/features/refunds/constants";

export function RefundsBoard() {
  const [status, setStatus] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCode, setSelectedCode] = useState("");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);
  const [dateRange, setDateRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });

  const effectiveStatus = status;

  const {
    data,
    isPending,
    isError,
    error: queryError,
    refetch,
  } = useRefundsQuery({
    page,
    limit: pageSize,
    q: searchQuery,
    status: effectiveStatus,
  });

  const forbidden = isError && isForbiddenError(queryError);

  const rawItems = useMemo(() => data?.items ?? [], [data?.items]);
  const total = data?.total ?? 0;

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const items = useMemo(() => {
    return rawItems.filter((item) =>
      isDateWithinRange(item.createdAt, dateRange),
    );
  }, [rawItems, dateRange]);

  const errorMessage = queryError
    ? queryError instanceof Error
      ? queryError.message
      : "Không thể tải danh sách hoàn tiền."
    : null;

  const selectedRefund =
    items.find((item) => item.code === selectedCode) ?? items[0] ?? null;

  const refundKpis = useMemo(() => {
    const awaiting = filteredStatusKpi({
      statusFilter: effectiveStatus,
      targetStatus: "AWAITING_REVIEW",
      total,
      pageCount: items.filter((item) => item.status === "AWAITING_REVIEW")
        .length,
    });
    const processing = filteredStatusKpi({
      statusFilter: effectiveStatus,
      targetStatus: "PROCESSING",
      total,
      pageCount: items.filter((item) => item.status === "PROCESSING").length,
    });
    const refunded = filteredStatusKpi({
      statusFilter: effectiveStatus,
      targetStatus: "REFUNDED",
      total,
      pageCount: items.filter((item) => item.status === "REFUNDED").length,
    });
    const rejected = filteredStatusKpi({
      statusFilter: effectiveStatus,
      targetStatus: "REJECTED",
      total,
      pageCount: items.filter((item) => item.status === "REJECTED").length,
    });
    return [
      {
        label: "Tổng yêu cầu",
        value: total,
        note: "theo bộ lọc",
        tone: "brand" as const,
        icon: "receipt" as const,
      },
      {
        label: "Chờ kiểm tra",
        value: awaiting.value,
        note: awaiting.note,
        tone: "food" as const,
        icon: "clock" as const,
      },
      {
        label: "Đang xử lý",
        value: processing.value,
        note: processing.note,
        tone: "delivery" as const,
        icon: "wallet" as const,
      },
      {
        label: "Đã hoàn",
        value: refunded.value,
        note: refunded.note,
        tone: "success" as const,
        icon: "check" as const,
      },
      {
        label: "Từ chối",
        value: rejected.value,
        note: rejected.note,
        tone: "danger" as const,
        icon: "close" as const,
      },
    ];
  }, [effectiveStatus, items, total]);

  const relatedRoute = selectedRefund
    ? resolveRefundOrderRoute(selectedRefund.service, selectedRefund.orderCode)
    : null;

  const handleResetFilters = () => {
    setStatus(null);
    setSearchQuery("");
    setDateRange({ from: null, to: null });
    setPage(1);
  };

  const handleDateRangeChange = (newRange: DateRangeValue) => {
    setDateRange(newRange);
    setPage(1);
  };

  const handleStatusChange = (selectedStatus: string | null) => {
    setStatus(selectedStatus);
    setPage(1);
  };

  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(event.target.value);
    setPage(1);
  };

  const handlePageChange = (targetPage: number) => {
    setPage(targetPage);
  };

  const handlePageSizeChange = (newSize: PageSize) => {
    setPageSize(newSize);
    setPage(1);
  };

  return (
    <div className="space-y-5">
      {errorMessage && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message={errorMessage}
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài chính", href: "/transactions" },
          { label: "Yêu cầu hoàn tiền" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Xử lý hoàn tiền
          </h1>
          <p className="mt-1 text-sm text-muted">
            Kiểm tra giao dịch gốc, bằng chứng và quyết định hoàn — không đồng
            nghĩa đã hoàn.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={handleDateRangeChange}
            defaultPreset="all"
          />
          <ExportCsvButton
            filename="refunds.csv"
            headers={["Mã", "Trạng thái"]}
            rows={items.map((item) => [item.code, item.status])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {refundKpis.map((kpi) => (
          <li key={kpi.label}>
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              note={kpi.note}
              icon={kpi.icon}
              tone={kpi.tone}
            />
          </li>
        ))}
      </ul>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={refundStatusOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={handleStatusChange}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="refund-query"
              className="text-xs font-medium text-muted"
            >
              Tìm yêu cầu hoàn tiền
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="refund-query"
                type="search"
                autoComplete="off"
                value={searchQuery}
                onChange={handleSearchChange}
                placeholder="Mã hoàn tiền, mã đơn, khách hàng..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton onClick={handleResetFilters} />
          </div>
        </AdminFilterToolbar>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập yêu cầu hoàn tiền"
          description="Tài khoản Ops hiện tại không được cấp quyền xem hoặc đối soát các giao dịch hoàn tiền."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message={errorMessage ?? "Lỗi tải dữ liệu yêu cầu hoàn tiền."}
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="receipt"
          title="Không có yêu cầu hoàn tiền phù hợp"
          description="Thử đổi bộ lọc trạng thái hoặc từ khóa tìm kiếm."
          action={
            <AdminResetFilterButton
              onClick={handleResetFilters}
              label="Xóa bộ lọc"
            />
          }
        />
      ) : (
        <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(18rem,22rem)]">
          <div className="min-w-0 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 px-1">
              <h2 className="text-sm font-semibold text-ink">
                Danh sách hoàn tiền
              </h2>
              <p className="text-sm text-muted">Sắp xếp: Mới nhất</p>
            </div>
            <AdminTableContainer>
              <AdminTable minWidth="min-w-[760px]" ariaBusy={isPending}>
                <AdminTableHeader>
                  <AdminTableRow>
                    {REFUND_TABLE_COLUMNS.map((col) => (
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
                      columns={REFUND_COLUMN_COUNT}
                      rows={6}
                    />
                  ) : (
                    items.map((item) => {
                      const isSelected = item.code === selectedRefund?.code;
                      return (
                        <AdminTableRow
                          key={item.code}
                          onClick={() => setSelectedCode(item.code)}
                          className={`cursor-pointer ${
                            isSelected
                              ? "bg-brand/5 ring-1 ring-inset ring-brand/30"
                              : ""
                          }`}
                        >
                          <AdminTableCell className="font-semibold text-brand">
                            {item.code}
                          </AdminTableCell>
                          <AdminTableCell className="font-medium">
                            {item.orderCode}
                          </AdminTableCell>
                          <AdminTableCell>{item.customer}</AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {item.service}
                          </AdminTableCell>
                          <AdminTableCell
                            align="right"
                            className="font-semibold tabular-nums"
                          >
                            {vnd(item.amount)}
                          </AdminTableCell>
                          <AdminTableCell className="max-w-xs truncate text-muted">
                            {item.reason}
                          </AdminTableCell>
                          <AdminTableCell>
                            <StatusChip tone={refundStatusTone(item.status)}>
                              {refundStatusLabel(item.status)}
                            </StatusChip>
                          </AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {item.createdAt}
                          </AdminTableCell>
                        </AdminTableRow>
                      );
                    })
                  )}
                </AdminTableBody>
              </AdminTable>
            </AdminTableContainer>
            <ListPager
              page={currentPage}
              pageSize={pageSize}
              summary={`Hiển thị ${items.length} / ${countFormat.format(total)} yêu cầu`}
              label="Phân trang danh sách hoàn tiền"
              onPageChange={handlePageChange}
              onPageSizeChange={handlePageSizeChange}
              lastPage={lastPage}
            />
          </div>

          {selectedRefund ? (
            <aside
              aria-label="Chi tiết yêu cầu hoàn tiền"
              className="min-w-0 space-y-4"
            >
              <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-xs font-semibold text-muted">
                      Yêu cầu hoàn tiền
                    </p>
                    <p className="mt-1 font-mono text-base font-bold text-ink">
                      {selectedRefund.code}
                    </p>
                  </div>
                  <StatusChip tone={refundStatusTone(selectedRefund.status)}>
                    {refundStatusLabel(selectedRefund.status)}
                  </StatusChip>
                </div>

                <dl className="mt-4 space-y-3 text-sm">
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Đơn hàng gốc</dt>
                    <dd className="font-medium text-ink">
                      {selectedRefund.orderCode}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Dịch vụ</dt>
                    <dd className="font-medium text-ink">
                      {selectedRefund.service}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Khách hàng</dt>
                    <dd className="font-medium text-ink">
                      {selectedRefund.customer}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Số tiền hoàn</dt>
                    <dd className="font-bold text-brand tabular-nums">
                      {vnd(selectedRefund.amount)}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted">Lý do khiếu nại</dt>
                    <dd className="mt-1 rounded-xl border border-border bg-canvas/60 p-3 text-xs leading-relaxed text-ink">
                      {selectedRefund.reason}
                    </dd>
                  </div>
                </dl>

                {relatedRoute ? (
                  <div className="mt-4 pt-3 border-t border-border">
                    <Link
                      href={relatedRoute}
                      className="inline-flex w-full items-center justify-center gap-1.5 rounded-xl border border-border bg-white px-3 py-2 text-xs font-semibold text-brand hover:bg-canvas cursor-pointer"
                    >
                      <OpsIcon name="receipt" className="size-3.5" />
                      Xem đơn hàng gốc ({selectedRefund.orderCode})
                    </Link>
                  </div>
                ) : null}
              </section>
            </aside>
          ) : null}
        </div>
      )}
    </div>
  );
}
