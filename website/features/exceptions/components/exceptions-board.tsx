"use client";

import Link from "next/link";
import { toast } from "sonner";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  focusRing,
  formatCount,
  KpiCard,
  ListPager,
  StatusChip,
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
import {
  useExceptionListFilters,
  useExceptionsQuery,
} from "@/features/exceptions/hooks";
import {
  exceptionDomainLabel,
  exceptionEntityHref,
  exceptionPriorityLabel,
  exceptionPriorityTone,
  exceptionStatusFilterOptions,
  exceptionStatusLabel,
  exceptionStatusTone,
} from "@/features/exceptions/mappers";
import { coercePageSize, type PageSize } from "@/lib/admin-pagination";
import { isForbiddenError } from "@/lib/api/errors";

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
  EXCEPTION_COLUMN_COUNT,
  EXCEPTION_TABLE_COLUMNS,
} from "@/features/exceptions/constants";

export function ExceptionsBoard() {
  const [filters, setFilters] = useExceptionListFilters();
  const { data, isPending, isError, error, refetch } = useExceptionsQuery();
  const items = data?.items ?? [];
  const total = data?.total ?? 0;
  const forbidden = isError && isForbiddenError(error);

  const resetFilters = () => {
    void setFilters({ q: "", status: "ALL", page: 1 });
  };

  const onPageSizeChange = (size: PageSize) => {
    void setFilters({ limit: size, page: 1 });
  };

  const openCount = items.filter((item) => item.status === "OPEN").length;
  const escalatedCount = items.filter(
    (item) => item.status === "ESCALATED",
  ).length;
  const p1Count = items.filter((item) => item.priority === "P1").length;

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không tải được hàng đợi ngoại lệ. Thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Ngoại lệ", href: "/exceptions" },
          { label: "Hàng đợi" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Hàng đợi ngoại lệ
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi và xử lý các chuyến đi hoặc đơn hàng có dấu hiệu kẹt, gián
            đoạn hoặc kết thúc bất thường.
          </p>
        </div>
        <button
          type="button"
          disabled={isPending}
          onClick={() => {
            void refetch();
            toast.success("Đã làm mới hàng đợi ngoại lệ");
          }}
          className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink shadow-xs transition-colors hover:bg-canvas hover:border-brand/40 cursor-pointer ${focusRing}`}
          title="Bấm để kiểm tra và làm mới các ca ngoại lệ"
        >
          <span className="relative flex size-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex size-2 rounded-full bg-emerald-500" />
          </span>
          <span>Giám sát trực tuyến · Làm mới</span>
          <OpsIcon
            name="refresh"
            className={`size-3.5 text-muted ${isPending ? "animate-spin text-brand" : ""}`}
          />
        </button>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <li>
          <KpiCard
            label="Tổng trong bộ lọc"
            value={total}
            icon="alert"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đang mở (trang)"
            value={openCount}
            icon="clock"
            tone="danger"
            note="trên trang hiện tại"
          />
        </li>
        <li>
          <KpiCard
            label="Leo thang (trang)"
            value={escalatedCount}
            icon="trend"
            tone="food"
            note="trên trang hiện tại"
          />
        </li>
        <li>
          <KpiCard
            label="Ưu tiên P1 (trang)"
            value={p1Count}
            icon="shield"
            tone="danger"
            note="trên trang hiện tại"
          />
        </li>
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField grow>
            <label
              htmlFor="exceptions-query"
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
                id="exceptions-query"
                type="search"
                autoComplete="off"
                value={filters.q}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                placeholder="Mã case, tiêu đề, thực thể liên quan..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={filters.status === "ALL" ? null : filters.status}
              options={exceptionStatusFilterOptions.filter(
                (o) => o.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={(next) => {
                void setFilters({
                  status: (next ?? "ALL") as typeof filters.status,
                  page: 1,
                });
              }}
            />
          </AdminFilterField>
          <div className="flex shrink-0 items-end">
            <button
              type="button"
              onClick={resetFilters}
              className={`inline-flex h-10 items-center justify-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink ${focusRing}`}
            >
              <OpsIcon name="undo" className="size-4" />
              Đặt lại
            </button>
          </div>
        </AdminFilterToolbar>
      </section>
      {forbidden ? (
        <AdminForbiddenState />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Không tải được hàng đợi ngoại lệ. Thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="alert"
          title="Không có ngoại lệ phù hợp"
          description="Không tìm thấy ngoại lệ nào phù hợp với bộ lọc hiện tại. Thử đổi từ khóa hoặc trạng thái."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <div className="flex flex-wrap items-center gap-2">
              <h2
                id="exceptions-table-title"
                className="text-sm font-semibold text-ink"
              >
                Hàng đợi xử lý
              </h2>
              {p1Count > 0 ? (
                <StatusChip tone="danger">
                  {p1Count} ưu tiên P1 trên trang
                </StatusChip>
              ) : null}
            </div>
            <p className="text-sm text-muted">
              {formatCount(total)} mục · trang {filters.page}
            </p>
          </div>
          <AdminTableContainer minWidth="min-w-240">
            <AdminTable ariaBusy={isPending} caption="Danh sách ngoại lệ">
              <AdminTableHeader>
                <AdminTableRow>
                  {EXCEPTION_TABLE_COLUMNS.map((col) => (
                    <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
                  ))}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer columns={EXCEPTION_COLUMN_COUNT} />
                ) : (
                  items.map((item) => {
                    const href = exceptionEntityHref(item);
                    return (
                      <AdminTableRow key={item.code}>
                        <AdminTableCell className="font-semibold text-brand">
                          {item.code}
                        </AdminTableCell>
                        <AdminTableCell className="max-w-xs">
                          {item.title}
                        </AdminTableCell>
                        <AdminTableCell>
                          {exceptionDomainLabel(item.domain)}
                        </AdminTableCell>
                        <AdminTableCell>
                          {href ? (
                            <Link
                              href={href}
                              className={`font-medium text-brand ${focusRing}`}
                            >
                              {item.entityRef}
                            </Link>
                          ) : (
                            <span className="text-muted">{item.entityRef}</span>
                          )}
                        </AdminTableCell>
                        <AdminTableCell>
                          <StatusChip tone={exceptionStatusTone(item.status)}>
                            {exceptionStatusLabel(item.status)}
                          </StatusChip>
                        </AdminTableCell>
                        <AdminTableCell>
                          <StatusChip
                            tone={exceptionPriorityTone(item.priority)}
                          >
                            {exceptionPriorityLabel(item.priority)}
                          </StatusChip>
                        </AdminTableCell>
                        <AdminTableCell className="text-muted">
                          {item.openedAt}
                        </AdminTableCell>
                      </AdminTableRow>
                    );
                  })
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager
            page={filters.page}
            onPageChange={(p) => void setFilters({ page: p })}
            summary={`Hiển thị ${items.length} / ${formatCount(total)} ngoại lệ`}
            label="Phân trang ngoại lệ"
            lastPage={Math.max(
              1,
              Math.ceil(total / Math.max(1, filters.limit)),
            )}
            pageSize={coercePageSize(filters.limit)}
            onPageSizeChange={onPageSizeChange}
          />
        </div>
      )}
    </div>
  );
}
