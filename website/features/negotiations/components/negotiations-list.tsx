"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  useNegotiationsFilters,
  useNegotiationsQuery,
} from "@/features/negotiations/hooks";
import type { NegotiationSession } from "@/features/negotiations/api";
import {
  negotiationSessionStatusLabel,
  negotiationSessionStatusTone,
} from "@/features/negotiations/mappers";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  focusRing,
  KpiCard,
  ListPager,
  PreviewButton,
  PreviewIconLink,
  StatusChip,
  vnd,
  ExportCsvButton,
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
import {
  DateRangePicker,
  type DateRangeValue,
} from "@/components/ui/date-picker";
import { SearchSelect } from "@/components/ui/search-select";
import {
  negotiationStatusOptions,
  useLiveRegionFilterOptions,
} from "@/lib/admin-filter-options";
import { filteredStatusKpi } from "@/lib/admin-kpi";
import { isForbiddenError } from "@/lib/api/errors";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";

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
  NEGOTIATION_COLUMN_COUNT,
  NEGOTIATION_TABLE_COLUMNS,
} from "@/features/negotiations/constants";

export function NegotiationsList() {
  const router = useRouter();
  const { options: regionOptions } = useLiveRegionFilterOptions();
  const [filters, setFilters] = useNegotiationsFilters();
  const { data, isPending, isError, error, refetch } = useNegotiationsQuery();
  const forbidden = isError && isForbiddenError(error);

  const [dateRange, setDateRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });

  const items: NegotiationSession[] = data?.items ?? [];
  const total = data?.total ?? 0;

  const region = filters.region || null;
  const status = filters.status || null;
  const query = filters.q;
  const page = filters.page;
  const pageSize = (filters.limit as PageSize) || 10;

  const resetFilters = () => {
    setDateRange({ from: null, to: null });
    void setFilters({ region: "", status: "", q: "", page: 1 });
  };

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const openKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "OPEN",
    total,
    pageCount: items.filter((row) => row.status === "OPEN").length,
  });
  const acceptedKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "ACCEPTED",
    total,
    pageCount: items.filter((row) => row.status === "ACCEPTED").length,
  });
  const expiredKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "EXPIRED",
    total,
    pageCount: items.filter((row) => row.status === "EXPIRED").length,
  });
  const lockedKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "LOCKED",
    total,
    pageCount: items.filter((row) => row.status === "LOCKED").length,
  });

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách phiên trả giá mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Phiên trả giá", href: "/negotiations" },
          { label: "Danh sách" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách phiên trả giá
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi phiên thương lượng giá chuyến xe giữa khách và tài xế.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={setDateRange}
            defaultPreset="today"
          />
          <ExportCsvButton
            filename="negotiations.csv"
            headers={[
              "Mã",
              "Khách",
              "Tuyến",
              "Ngân sách",
              "Thấp nhất",
              "Trạng thái",
            ]}
            rows={items.map((s) => [
              s.code,
              s.customer,
              s.route,
              String(s.budget),
              s.lowest == null ? "" : String(s.lowest),
              s.status,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <li>
          <KpiCard
            label="Tổng phiên"
            value={total}
            note="theo bộ lọc"
            icon="gavel"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đang mở"
            value={openKpi.value}
            note={openKpi.note}
            icon="clock"
            tone="delivery"
          />
        </li>
        <li>
          <KpiCard
            label="Đã chốt"
            value={acceptedKpi.value}
            note={acceptedKpi.note}
            icon="check"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Hết hạn / hủy"
            value={expiredKpi.value}
            note={expiredKpi.note}
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Đã gán / khóa"
            value={lockedKpi.value}
            note={lockedKpi.note}
            icon="shield"
            tone="danger"
          />
        </li>
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[12rem]">
            <DateRangePicker
              label="Thời gian"
              value={dateRange}
              onChange={setDateRange}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Khu vực"
              icon="pin"
              value={region}
              options={regionOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả khu vực"
              onChange={(v) => {
                void setFilters({ region: v || "", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={negotiationStatusOptions.filter(
                (o) => o.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={(v) => {
                void setFilters({ status: v || "", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="negotiations-query"
              className="text-xs font-medium text-muted"
            >
              Tìm phiên trả giá
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="negotiations-query"
                type="search"
                autoComplete="off"
                value={query}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                placeholder="Tìm mã phiên, điểm đón/trả, khách hàng..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 flex-wrap items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton onClick={resetFilters} />
          </div>
        </AdminFilterToolbar>
      </section>
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập phiên trả giá"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc quản lý phiên thương lượng giá."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách phiên trả giá."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="car"
          title="Không tìm thấy phiên trả giá"
          description="Không có phiên trả giá nào khớp với điều kiện lọc hiện tại. Thử xóa bộ lọc để hiển thị toàn bộ."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer minWidth="min-w-[1080px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách phiên trả giá">
              <AdminTableHeader>
                <AdminTableRow>
                  {NEGOTIATION_TABLE_COLUMNS.map((col) => (
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
                    columns={NEGOTIATION_COLUMN_COUNT}
                    rows={5}
                  />
                ) : (
                  items.map((session) => (
                    <AdminTableRow
                      key={session.code}
                      className="cursor-pointer"
                      onClick={() => {
                        router.push(`/negotiations/${session.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/negotiations/${session.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell className="font-semibold text-brand">
                        {session.code.slice(0, 8)}…
                      </AdminTableCell>
                      <AdminTableCell className="font-medium">
                        {session.customer}
                      </AdminTableCell>
                      <AdminTableCell className="max-w-[16rem] truncate">
                        <RouteLabel route={session.route} />
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {vnd(session.budget)}
                      </AdminTableCell>
                      <AdminTableCell
                        align="right"
                        className="font-semibold text-success tabular-nums"
                      >
                        {session.lowest == null ? "—" : vnd(session.lowest)}
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {session.bids}
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink">{session.expires}</p>
                        <p className="text-xs text-muted">
                          {session.expiresDate}
                        </p>
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip
                          tone={negotiationSessionStatusTone(session.status)}
                        >
                          {negotiationSessionStatusLabel(session.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/negotiations/${session.code}`}
                          label={`Xem phiên ${session.code}`}
                        >
                          <OpsIcon name="eye" className="size-4" />
                        </PreviewIconLink>
                      </AdminTableCell>
                    </AdminTableRow>
                  ))
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager
            page={currentPage}
            pageSize={pageSize}
            onPageChange={(p) => void setFilters({ page: p })}
            onPageSizeChange={(ps) => void setFilters({ limit: ps, page: 1 })}
            summary={`Hiển thị ${items.length} / ${countFormat.format(total)} phiên`}
            label="Phân trang phiên trả giá"
            lastPage={lastPage}
          />
        </div>
      )}
    </div>
  );
}

function RouteLabel({ route }: { route: string }) {
  const parts = route.split(" → ");
  if (parts.length < 2) {
    return <span>{route}</span>;
  }
  return (
    <span className="inline-flex max-w-full items-center gap-1">
      <span className="truncate">{parts[0]}</span>
      <OpsIcon name="arrowRight" className="size-3.5 shrink-0 text-muted" />
      <span className="truncate">{parts[1]}</span>
    </span>
  );
}
