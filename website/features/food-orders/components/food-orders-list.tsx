"use client";

import { useRouter } from "next/navigation";
import { useCallback, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  ExportCsvButton,
  focusRing,
  formatCount,
  KpiCard,
  ListPager,
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
import {
  DateRangePicker,
  type DateRangeValue,
} from "@/components/ui/date-picker";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import {
  SearchSelect,
  type SearchSelectOption,
} from "@/components/ui/search-select";
import {
  useFoodOrderListFilters,
  useFoodOrdersQuery,
} from "@/features/food-orders/hooks";
import {
  foodOrderStatusFilterOptions,
  foodOrderStatusLabel,
  foodOrderStatusTabs,
  foodOrderStatusTone,
} from "@/features/food-orders/mappers";
import type { FoodOrderListItem } from "@/features/food-orders/types";
import {
  paymentMethodOptions,
  useLiveRegionFilterOptions,
} from "@/lib/admin-filter-options";
import { filteredStatusKpi } from "@/lib/admin-kpi";
import { coercePageSize, type PageSize } from "@/lib/admin-pagination";
import { isForbiddenError } from "@/lib/api/errors";
import { fetchStores } from "@/features/stores/api";

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
  FOOD_ORDER_COLUMN_COUNT,
  FOOD_ORDER_TABLE_COLUMNS,
} from "@/features/food-orders/constants";

async function searchStores(query: string): Promise<SearchSelectOption[]> {
  const page = await fetchStores({
    page: 1,
    limit: 20,
    q: query.trim() || undefined,
  });
  return page.items.map((store) => ({
    value: store.code,
    label: store.name,
    description: store.area,
  }));
}

export function FoodOrdersList() {
  const router = useRouter();
  const [filters, setFilters] = useFoodOrderListFilters();
  const { options: regionOptions } = useLiveRegionFilterOptions();
  const { data, isPending, isError, error, refetch } = useFoodOrdersQuery();
  const items: FoodOrderListItem[] = data?.items ?? [];
  const total = data?.total ?? items.length;
  const forbidden = isError && isForbiddenError(error);
  const [dateRange, setDateRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });
  const loadStores = useCallback((query: string) => searchStores(query), []);

  const resetFilters = () => {
    setDateRange({ from: null, to: null });
    void setFilters({
      q: "",
      status: "ALL",
      store: "ALL",
      payment: "ALL",
      zone: "ALL",
      page: 1,
    });
  };

  const onPageSizeChange = (size: PageSize) => {
    void setFilters({ limit: size, page: 1 });
  };

  const awaitingKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "AWAITING_CONFIRMATION",
    total,
    pageCount: items.filter((row) => row.status === "AWAITING_CONFIRMATION")
      .length,
  });
  const preparingKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "PREPARING",
    total,
    pageCount: items.filter((row) => row.status === "PREPARING").length,
  });
  const deliveringKpi = filteredStatusKpi({
    statusFilter: filters.status,
    targetStatus: "DELIVERING",
    total,
    pageCount: items.filter((row) => row.status === "DELIVERING").length,
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
    row.store,
    foodOrderStatusLabel(row.status),
    String(row.total),
    row.payment,
    row.driver ?? "",
    row.time,
  ]);

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ dữ liệu đơn đồ ăn mới nhất từ máy chủ."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Đơn đồ ăn", href: "/food-orders" },
          { label: "Danh sách" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Quản lý đơn đồ ăn
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi và điều phối đơn từ nhà hàng đến khách hàng theo thời gian
            thực.
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
            filename="food-orders"
            headers={[
              "Mã",
              "Khách",
              "Quán",
              "Trạng thái",
              "Tổng",
              "Thanh toán",
              "Tài xế",
              "Thời gian",
            ]}
            rows={exportRows}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất báo cáo
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <li>
          <KpiCard
            label="Tổng đơn hôm nay"
            value={total}
            note={"theo bộ lọc"}
            icon="utensils"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Chờ xác nhận"
            value={awaitingKpi.value}
            note={awaitingKpi.note}
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Đang chuẩn bị"
            value={preparingKpi.value}
            note={preparingKpi.note}
            icon="store"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Đang giao"
            value={deliveringKpi.value}
            note={deliveringKpi.note}
            icon="package"
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
            icon="alert"
            tone="danger"
          />
        </li>
      </ul>
      <div className="min-w-0 overflow-x-auto">
        <ul
          aria-label="Lọc theo trạng thái đơn"
          className="flex w-max min-w-full gap-2 pb-1"
        >
          {foodOrderStatusTabs.map((item) => {
            const selected = filters.status === item.value;
            return (
              <li key={item.value}>
                <button
                  type="button"
                  aria-pressed={selected}
                  onClick={() => {
                    void setFilters({ status: item.value, page: 1 });
                  }}
                  className={
                    selected
                      ? `inline-flex h-9 items-center rounded-full bg-brand/10 px-3 text-sm font-semibold whitespace-nowrap text-brand ${focusRing}`
                      : `inline-flex h-9 items-center rounded-full border border-border bg-white px-3 text-sm whitespace-nowrap text-ink ${focusRing}`
                  }
                >
                  {item.label} {item.count}
                </button>
              </li>
            );
          })}
        </ul>
      </div>
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
              value={filters.zone === "ALL" ? null : filters.zone}
              options={regionOptions.filter((option) => option.value !== "ALL")}
              placeholder="Tất cả khu vực"
              onChange={(nextZone) =>
                void setFilters({ zone: nextZone ?? "ALL", page: 1 })
              }
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[12rem]">
            <SearchSelect
              label="Cửa hàng"
              value={filters.store === "ALL" ? null : filters.store}
              placeholder="Tất cả cửa hàng"
              loadOptions={loadStores}
              onChange={(nextStore) =>
                void setFilters({ store: nextStore ?? "ALL", page: 1 })
              }
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Thanh toán"
              icon="wallet"
              value={filters.payment === "ALL" ? null : filters.payment}
              options={paymentMethodOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Mọi phương thức"
              onChange={(nextPayment) =>
                void setFilters({ payment: nextPayment ?? "ALL", page: 1 })
              }
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={filters.status === "ALL" ? null : filters.status}
              options={foodOrderStatusFilterOptions.filter(
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
              htmlFor="food-orders-query"
              className="text-xs font-medium text-muted"
            >
              Tìm đơn đồ ăn
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="food-orders-query"
                type="search"
                autoComplete="off"
                value={filters.q}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                placeholder="Tìm mã đơn, khách hàng, quán ăn, tài xế..."
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
              filename="food-orders"
              headers={[
                "Mã",
                "Khách",
                "Quán",
                "Trạng thái",
                "Tổng",
                "Thanh toán",
                "Tài xế",
                "Thời gian",
              ]}
              rows={exportRows}
            >
              <OpsIcon name="download" className="size-4" />
              Xuất CSV
            </ExportCsvButton>
          </div>
        </AdminFilterToolbar>
      </section>
      {forbidden ? (
        <AdminForbiddenState />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách đơn đồ ăn từ máy chủ. Vui lòng kiểm tra lại kết nối mạng hoặc thử lại."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="utensils"
          title="Không có đơn đồ ăn phù hợp"
          description="Thử đổi tab trạng thái hoặc từ khóa tìm kiếm."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer minWidth="min-w-[1080px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách đơn đồ ăn">
              <AdminTableHeader>
                <AdminTableRow>
                  {FOOD_ORDER_TABLE_COLUMNS.map((col) => (
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
                  <AdminTableBodyShimmer columns={FOOD_ORDER_COLUMN_COUNT} />
                ) : (
                  items.map((order) => (
                    <AdminTableRow
                      key={order.code}
                      className="cursor-pointer align-top"
                      onClick={() => {
                        router.push(`/food-orders/${order.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/food-orders/${order.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell>
                        <p className="font-semibold text-brand">{order.code}</p>
                        <p className="text-xs text-muted">Đơn đồ ăn</p>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="font-medium text-ink">{order.customer}</p>
                        <p className="text-xs text-muted">Khách hàng</p>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="font-medium text-ink">{order.store}</p>
                        <p className="text-xs text-muted">
                          {order.regionLabel}
                        </p>
                      </AdminTableCell>
                      <AdminTableCell>{order.items}</AdminTableCell>
                      <AdminTableCell align="right">
                        <p className="font-semibold text-ink tabular-nums">
                          {vnd(order.total)}
                        </p>
                        <p className="text-xs text-muted">{order.payment}</p>
                      </AdminTableCell>
                      <AdminTableCell>
                        {order.driver ? (
                          <span className="text-ink">{order.driver}</span>
                        ) : (
                          <span className="text-muted">Chưa phân công</span>
                        )}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={foodOrderStatusTone(order.status)}>
                          {foodOrderStatusLabel(order.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink text-sm">{order.time}</p>
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/food-orders/${order.code}`}
                          label={`Xem đơn ${order.code}`}
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
            summary={`Hiển thị ${items.length} / ${formatCount(total)} đơn`}
            label="Phân trang đơn đồ ăn"
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
