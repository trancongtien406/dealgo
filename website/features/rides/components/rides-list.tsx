"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  ExportCsvButton,
  focusRing,
  formatCount,
  KpiCard,
  ListPager,
  personInitials,
  PreviewButton,
  PreviewIconLink,
  StatusChip,
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
import { LazyRealMapView } from "@/components/ui/lazy-real-map-view";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import {
  DateRangePicker,
  type DateRangeValue,
} from "@/components/ui/date-picker";
import { SearchSelect } from "@/components/ui/search-select";
import { useRideListFilters, useRidesQuery } from "@/features/rides/hooks";
import {
  rideStatusFilterOptions,
  rideStatusLabel,
  rideStatusTone,
} from "@/features/rides/mappers";
import type { RideListItem } from "@/features/rides/types";
import { useLiveRegionFilterOptions } from "@/lib/admin-filter-options";
import { filteredStatusKpi } from "@/lib/admin-kpi";
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
  RIDE_COLUMN_COUNT,
  RIDE_TABLE_COLUMNS,
} from "@/features/rides/constants";

export function RidesList() {
  const router = useRouter();
  const [filters, setFilters] = useRideListFilters();
  const [dateRange, setDateRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });
  const [isMapVisible, setIsMapVisible] = useState(true);
  const [isMapExpanded, setIsMapExpanded] = useState(false);

  const { data, isPending, isError, error, refetch } = useRidesQuery();
  const { options: regionOptions } = useLiveRegionFilterOptions();
  const items: RideListItem[] = data?.items ?? [];
  const total = data?.total ?? items.length;
  const forbidden = isError && isForbiddenError(error);

  const resetFilters = () => {
    setDateRange({ from: null, to: null });
    void setFilters({
      q: "",
      status: "ALL",
      zone: "ALL",
      page: 1,
    });
  };

  const onPageSizeChange = (size: PageSize) => {
    void setFilters({ limit: size, page: 1 });
  };

  const waitingKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "WAITING",
    total,
    pageCount: items.filter((row) => row.status === "WAITING").length,
  });
  const activeKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: ["PICKING_UP", "IN_TRIP"],
    total,
    pageCount: items.filter(
      (row) => row.status === "PICKING_UP" || row.status === "IN_TRIP",
    ).length,
  });
  const completedKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "COMPLETED",
    total,
    pageCount: items.filter((row) => row.status === "COMPLETED").length,
  });
  const cancelledKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "CANCELLED",
    total,
    pageCount: items.filter((row) => row.status === "CANCELLED").length,
  });

  const exportRows = items.map((row) => [
    row.code,
    row.customer,
    row.driver,
    row.pickup,
    row.dropoff,
    rideStatusLabel(row.status),
    String(row.price),
    row.time,
  ]);

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ dữ liệu chuyến mới nhất từ máy chủ."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Chuyến xe", href: "/rides" },
          { label: "Quản lý chuyến xe" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Quản lý chuyến xe
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi và điều phối các chuyến xe 2 bánh, trạng thái cuốc và tiến
            độ tài xế.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={setDateRange}
            defaultPreset="today"
          />
          <ExportCsvButton
            tone="brand"
            filename="rides"
            headers={[
              "Mã",
              "Khách",
              "Tài xế",
              "Điểm đón",
              "Điểm đến",
              "Trạng thái",
              "Giá",
              "Thời gian",
            ]}
            rows={exportRows}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất báo cáo
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <li>
          <KpiCard
            label="Tất cả chuyến"
            value={total}
            note={"theo bộ lọc"}
            icon="car"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đang chờ tài xế"
            value={waitingKpi.value}
            note={waitingKpi.note}
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Đang diễn ra"
            value={activeKpi.value}
            note={activeKpi.note}
            icon="play"
            tone="delivery"
          />
        </li>
        <li>
          <KpiCard
            label="Hoàn thành"
            value={completedKpi.value}
            note={completedKpi.note}
            icon="check"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Đã hủy"
            value={cancelledKpi.value}
            note={cancelledKpi.note}
            icon="close"
            tone="danger"
          />
        </li>
      </ul>
      {isMapVisible && (
        <RideMapPreview
          isExpanded={isMapExpanded}
          onToggleExpand={() => setIsMapExpanded((prev) => !prev)}
          onClose={() => setIsMapVisible(false)}
        />
      )}

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <div className="min-w-0 space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <h2 className="text-base font-bold text-ink">
                Bộ lọc & danh sách chuyến xe
              </h2>
              <span className="rounded-full bg-brand/10 px-2.5 py-0.5 text-xs font-semibold text-brand">
                {total} cuốc
              </span>
            </div>
            {!isMapVisible && (
              <PreviewButton onClick={() => setIsMapVisible(true)}>
                <OpsIcon name="pin" className="size-4 text-brand" />
                Hiện bản đồ điều phối
              </PreviewButton>
            )}
          </div>
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
                value={filters.zone === "ALL" ? null : filters.zone}
                options={regionOptions.filter(
                  (option) => option.value !== "ALL",
                )}
                placeholder="Tất cả khu vực"
                onChange={(nextZone) =>
                  void setFilters({ zone: nextZone ?? "ALL", page: 1 })
                }
              />
            </AdminFilterField>
            <AdminFilterField>
              <SearchSelect
                label="Trạng thái"
                icon="sliders"
                value={filters.status === "ALL" ? null : filters.status}
                options={rideStatusFilterOptions.filter(
                  (option) => option.value !== "ALL",
                )}
                placeholder="Tất cả trạng thái"
                onChange={(nextStatus) => {
                  void setFilters({
                    status: (nextStatus ?? "ALL") as typeof filters.status,
                    page: 1,
                  });
                }}
              />
            </AdminFilterField>
            <AdminFilterField grow>
              <label
                htmlFor="rides-query"
                className="text-xs font-medium text-muted"
              >
                Tìm chuyến xe
              </label>
              <div className="relative mt-1.5">
                <OpsIcon
                  name="search"
                  className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
                />
                <input
                  id="rides-query"
                  type="search"
                  autoComplete="off"
                  value={filters.q}
                  onChange={(event) => {
                    void setFilters({ q: event.target.value, page: 1 });
                  }}
                  placeholder="Tìm kiếm mã chuyến, khách hàng, tài xế..."
                  className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
                />
              </div>
            </AdminFilterField>
            <div className="flex shrink-0 flex-wrap items-end gap-2">
              <PreviewButton onClick={() => void refetch()}>
                <OpsIcon name="refresh" className="size-4" />
                Làm mới
              </PreviewButton>
              <ExportCsvButton
                filename="rides"
                headers={[
                  "Mã",
                  "Khách",
                  "Tài xế",
                  "Đón",
                  "Trả",
                  "Trạng thái",
                  "Giá",
                  "Thời gian",
                ]}
                rows={exportRows}
              >
                <OpsIcon name="download" className="size-4" />
                Xuất dữ liệu
              </ExportCsvButton>
            </div>
          </AdminFilterToolbar>
        </div>
      </section>
      {forbidden ? (
        <AdminForbiddenState />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách chuyến xe từ máy chủ. Vui lòng kiểm tra lại kết nối mạng hoặc thử lại."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="car"
          title="Không có chuyến xe phù hợp"
          description="Thử đổi từ khóa hoặc trạng thái để tìm kiếm."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer minWidth="min-w-[1180px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách chuyến xe">
              <AdminTableHeader>
                <AdminTableRow>
                  <AdminTableHead className="w-12">
                    <input
                      type="checkbox"
                      aria-label="Chọn tất cả chuyến trên trang này"
                      className={`size-4 accent-brand ${focusRing}`}
                    />
                  </AdminTableHead>
                  {RIDE_TABLE_COLUMNS.filter((col) => col.id !== "select").map(
                    (col) => (
                      <AdminTableHead
                        key={col.id}
                        align={"align" in col ? col.align : "left"}
                      >
                        {col.label}
                      </AdminTableHead>
                    ),
                  )}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer columns={RIDE_COLUMN_COUNT} />
                ) : (
                  items.map((ride, index) => (
                    <AdminTableRow
                      key={ride.code}
                      className="cursor-pointer align-top"
                      onClick={() => {
                        router.push(`/rides/${ride.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/rides/${ride.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <input
                          type="checkbox"
                          aria-label={`Chọn chuyến ${ride.code}`}
                          className={`size-4 accent-brand ${focusRing}`}
                        />
                      </AdminTableCell>
                      <AdminTableCell className="font-semibold text-brand">
                        {ride.code.slice(0, 8)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <div className="flex items-center gap-2">
                          <Avatar
                            letters={personInitials(ride.customer)}
                            tone={avatarTone(index)}
                          />
                          <div className="min-w-0">
                            <p className="font-medium whitespace-nowrap text-ink">
                              {ride.customer}
                            </p>
                            <p className="text-xs whitespace-nowrap text-muted">
                              {ride.phone}
                            </p>
                          </div>
                        </div>
                      </AdminTableCell>
                      <AdminTableCell>
                        <div className="flex items-center gap-2">
                          <Avatar
                            letters={personInitials(ride.driver)}
                            tone={avatarTone(index + 1)}
                          />
                          <div>
                            <p className="font-medium whitespace-nowrap text-ink">
                              {ride.driver}
                            </p>
                            <p className="text-xs whitespace-nowrap text-muted">
                              {ride.plate}
                            </p>
                          </div>
                        </div>
                      </AdminTableCell>
                      <AdminTableCell>
                        <Place
                          name={ride.pickup}
                          area={ride.pickupArea}
                          tone="success"
                        />
                      </AdminTableCell>
                      <AdminTableCell>
                        <Place
                          name={ride.dropoff}
                          area={ride.dropoffArea}
                          tone="danger"
                        />
                      </AdminTableCell>
                      <AdminTableCell>
                        <span className="inline-flex items-center gap-1.5">
                          <OpsIcon name="car" className="size-4 text-muted" />
                          {ride.seats}
                        </span>
                      </AdminTableCell>
                      <AdminTableCell
                        align="right"
                        className="font-medium tabular-nums"
                      >
                        {vnd(ride.price)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={rideStatusTone(ride.status)}>
                          {rideStatusLabel(ride.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink text-sm">{ride.time}</p>
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <div className="flex items-center">
                          <PreviewIconLink
                            href={`/rides/${ride.code}`}
                            label={`Xem chuyến ${ride.code}`}
                          >
                            <OpsIcon name="eye" className="size-4" />
                          </PreviewIconLink>
                        </div>
                      </AdminTableCell>
                    </AdminTableRow>
                  ))
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager
            summary={
              isPending
                ? "Đang tải danh sách chuyến xe…"
                : `Hiển thị ${items.length} / ${formatCount(total)} chuyến xe`
            }
            label="Phân trang chuyến xe"
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
    </div>
  );
}

function Place({
  name,
  area,
  tone,
}: {
  name: string;
  area: string;
  tone: "success" | "danger";
}) {
  return (
    <div className="flex min-w-40 gap-2">
      <span
        aria-hidden="true"
        className={`mt-1.5 size-1.5 shrink-0 rounded-full ${tone === "success" ? "bg-success" : "bg-danger"}`}
      />
      <div className="min-w-0">
        <p className="font-medium text-ink">{name}</p>
        <p className="text-xs text-muted">{area}</p>
      </div>
    </div>
  );
}

function RideMapPreview({
  isExpanded = false,
  onToggleExpand,
  onClose,
}: {
  isExpanded?: boolean;
  onToggleExpand?: () => void;
  onClose?: () => void;
}) {
  return (
    <aside
      aria-label="Xem trước tuyến DGX-240610-1024, đang di chuyển tại Đà Nẵng"
      className="relative isolate overflow-hidden rounded-2xl border border-border bg-white shadow-sm transition-all duration-200"
    >
      {/* Live Dispatch Header Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border/80 bg-canvas/40 px-4 py-3">
        <div className="flex items-center gap-3">
          <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-brand/10 text-brand">
            <OpsIcon name="car" className="size-4.5" />
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-sm font-bold text-ink">
                DGX-240610-1024
              </span>
              <span className="rounded-full bg-emerald-50 px-2.5 py-0.5 text-[11px] font-semibold text-emerald-700">
                {rideStatusLabel("IN_TRIP")}
              </span>
              <span className="hidden text-xs text-muted sm:inline-block">
                ·
              </span>
              <span className="hidden text-xs font-medium text-ink sm:inline-block">
                Hải Châu → Sơn Trà (5.2 km · ~12 phút)
              </span>
            </div>
            <p className="text-xs text-muted">
              Tài xế: Lê Văn Nam (30A-123.45) · Điểm đón: 12 Lê Lợi · Điểm trả:
              24 Võ Nguyên Giáp
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {onToggleExpand && (
            <button
              type="button"
              onClick={onToggleExpand}
              className="inline-flex items-center gap-1.5 rounded-xl border border-border bg-white px-3 py-1.5 text-xs font-semibold text-ink shadow-xs hover:bg-canvas cursor-pointer transition-colors"
            >
              <OpsIcon
                name={isExpanded ? "close" : "overview"}
                className="size-3.5 text-muted"
              />
              <span>{isExpanded ? "Thu nhỏ (400px)" : "Mở rộng (520px)"}</span>
            </button>
          )}
          {onClose && (
            <button
              type="button"
              onClick={onClose}
              title="Ẩn bản đồ"
              className="rounded-xl border border-border bg-white p-2 text-muted hover:text-ink hover:bg-canvas cursor-pointer transition-colors"
            >
              <OpsIcon name="close" className="size-4" />
            </button>
          )}
        </div>
      </div>

      {/* Map View Canvas with generous height */}
      <div style={{ height: isExpanded ? 520 : 420 }}>
        <LazyRealMapView
          center={[16.061, 108.2208]}
          zoom={14}
          height="100%"
          route={[
            [16.0544, 108.2022], // Điểm đón: 12 Lê Lợi (Hải Châu)
            [16.0592, 108.2435], // Điểm trả: 24 Võ Nguyên Giáp (Sơn Trà / Mỹ Khê)
          ]}
          startLabel="12 Lê Lợi (Hải Châu)"
          endLabel="24 Võ Nguyên Giáp (Sơn Trà)"
          showControls={true}
          showAttribution={true}
          showDriverProgress={true}
        />
      </div>
    </aside>
  );
}
