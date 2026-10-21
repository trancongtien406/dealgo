"use client";

import { useRouter } from "next/navigation";
import {
  useDeliveriesFilters,
  useDeliveriesQuery,
} from "@/features/deliveries/hooks";
import { type DeliveryItem } from "@/features/deliveries/api";
import {
  deliveryStatusLabel,
  deliveryStatusTone,
} from "@/features/deliveries/mappers";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  focusRing,
  KpiCard,
  ListPager,
  ExportCsvButton,
  PreviewButton,
  PreviewIconLink,
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
import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import { SearchSelect } from "@/components/ui/search-select";
import { deliveryStatusOptions } from "@/lib/admin-filter-options";
import { filteredStatusKpi } from "@/lib/admin-kpi";
import { isForbiddenError } from "@/lib/api/errors";
import {
  DELIVERY_COLUMN_COUNT,
  DELIVERY_TABLE_COLUMNS,
} from "../constants";

export function DeliveriesList() {
  const router = useRouter();
  const [filters, setFilters] = useDeliveriesFilters();
  const { data, isPending, isError, error, refetch } = useDeliveriesQuery();

  const items: DeliveryItem[] = data?.items ?? [];
  const total = data?.total ?? 0;
  const status = filters.status || null;
  const query = filters.q;
  const page = filters.page;
  const pageSize = (filters.limit as PageSize) || 10;
  const forbidden = isError && isForbiddenError(error);

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const waitingKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "PENDING",
    total,
    pageCount: items.filter((row) => row.status === "WAITING_DRIVER").length,
  });
  const deliveringKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: ["DELIVERING", "PICKED_UP"],
    total,
    pageCount: items.filter(
      (row) => row.status === "DELIVERING" || row.status === "PICKED_UP",
    ).length,
  });
  const doneKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "DONE",
    total,
    pageCount: items.filter((row) => row.status === "COMPLETED").length,
  });
  const failedKpi = filteredStatusKpi({
    statusFilter: status,
    targetStatus: "CANCELLED",
    total,
    pageCount: items.filter((row) => row.status === "FAILED").length,
  });

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách đơn giao hàng mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Giao hàng", href: "/deliveries" },
          { label: "Danh sách đơn giao" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách đơn giao hàng
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi trạng thái điều phối giao nhận đơn đồ ăn (Food Delivery).
            Dữ liệu liên kết trực tiếp từ luồng giao vận của Food Orders.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter defaultPreset="today" />
          <ExportCsvButton
            filename="deliveries.csv"
            headers={["Mã", "Trạng thái"]}
            rows={items.map((order) => [order.code, order.status])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <li>
          <KpiCard
            label="Tổng đơn giao hàng"
            value={total}
            note="theo bộ lọc"
            icon="package"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Chờ nhận đơn"
            value={waitingKpi.value}
            note={waitingKpi.note}
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Đang giao hàng"
            value={deliveringKpi.value}
            note={deliveringKpi.note}
            icon="driver"
            tone="delivery"
          />
        </li>
        <li>
          <KpiCard
            label="Giao thành công"
            value={doneKpi.value}
            note={doneKpi.note}
            icon="check"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Giao thất bại"
            value={failedKpi.value}
            note={failedKpi.note}
            icon="alert"
            tone="danger"
          />
        </li>
      </ul>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={deliveryStatusOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả trạng thái"
              onChange={(v) => {
                void setFilters({ status: v || "", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="deliveries-query"
              className="text-xs font-medium text-muted"
            >
              Tìm đơn giao hàng
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="deliveries-query"
                type="search"
                autoComplete="off"
                value={query}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                placeholder="Tìm mã đơn, người gửi, tuyến đường, tài xế..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 flex-wrap items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton
              onClick={() => {
                void setFilters({ status: "", q: "", page: 1 });
              }}
            />
          </div>
        </AdminFilterToolbar>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập đơn giao hàng"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc xử lý phân hệ giao hàng."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách đơn giao hàng."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="package"
          title="Không có đơn giao hàng phù hợp"
          description="Thử đổi bộ lọc trạng thái hoặc từ khóa tìm kiếm."
          action={
            <AdminResetFilterButton
              onClick={() => {
                void setFilters({ status: "", q: "", page: 1 });
              }}
            />
          }
        />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer>
            <AdminTable minWidth={1080} caption="Danh sách đơn giao hàng">
              <AdminTableHeader>
                <AdminTableRow>
                  {DELIVERY_TABLE_COLUMNS.map((col) => (
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
                    columns={DELIVERY_COLUMN_COUNT}
                    rows={5}
                  />
                ) : (
                  items.map((order) => (
                    <AdminTableRow
                      key={order.code}
                      clickable
                      onClick={() => {
                        router.push(`/deliveries/${order.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/deliveries/${order.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell>
                        <p className="font-semibold text-brand">{order.code}</p>
                        <p className="text-xs text-muted">Giao hàng độc lập</p>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="font-medium text-ink">{order.sender}</p>
                        <p className="text-xs text-muted">Người gửi</p>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink">{order.route}</p>
                        <p className="text-xs text-muted">
                          {order.regionLabel ?? "—"}
                        </p>
                      </AdminTableCell>
                      <AdminTableCell>{order.cargo}</AdminTableCell>
                      <AdminTableCell
                        align="right"
                        className="font-semibold tabular-nums"
                      >
                        {vnd(order.fee)}
                      </AdminTableCell>
                      <AdminTableCell>
                        {order.driver ? (
                          <span className="text-ink">{order.driver}</span>
                        ) : (
                          <span className="text-xs text-muted">
                            Chưa chỉ định
                          </span>
                        )}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={deliveryStatusTone(order.status)}>
                          {deliveryStatusLabel(order.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink">{order.time}</p>
                      </AdminTableCell>
                      <AdminTableCell
                        align="center"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/deliveries/${order.code}`}
                          label={`Xem chi tiết ${order.code}`}
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
            onPageChange={(targetPage) => void setFilters({ page: targetPage })}
            onPageSizeChange={(newSize) =>
              void setFilters({ limit: newSize, page: 1 })
            }
            summary={`Hiển thị ${items.length} / ${countFormat.format(total)} đơn`}
            label="Phân trang đơn giao hàng"
            lastPage={lastPage}
          />
        </div>
      )}
    </div>
  );
}
