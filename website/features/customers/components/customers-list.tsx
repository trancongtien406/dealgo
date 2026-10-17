"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  countFormat,
  ExportCsvButton,
  focusRing,
  KpiCard,
  ListPager,
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
import { SearchSelect } from "@/components/ui/search-select";
import {
  useCustomerListFilters,
  useCustomersQuery,
} from "@/features/customers/hooks";
import {
  customerStatusFilterOptions,
  customerStatusLabel,
  customerStatusTone,
} from "@/features/customers/mappers";
import {
  serviceScopeOptions,
  useLiveRegionFilterOptions,
} from "@/lib/admin-filter-options";
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
  CUSTOMER_COLUMN_COUNT,
  CUSTOMER_TABLE_COLUMNS,
} from "@/features/customers/constants";

export function CustomersList() {
  const router = useRouter();
  const [filters, setFilters] = useCustomerListFilters();
  const { data, isPending, isError, error, refetch } = useCustomersQuery();
  const { options: regionOptions } = useLiveRegionFilterOptions();
  const items = data?.items ?? [];
  const total = data?.total ?? 0;
  const forbidden = isError && isForbiddenError(error);
  const [registeredRange, setRegisteredRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });

  const resetFilters = () => {
    setRegisteredRange({ from: null, to: null });
    void setFilters({
      q: "",
      status: "ALL",
      region: "ALL",
      service: "ALL",
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
          message="Không thể đồng bộ danh sách khách hàng mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Khách hàng", href: "/customers" },
          { label: "Danh sách" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách khách hàng
          </h1>
          <p className="mt-1 text-sm text-muted">
            Tra cứu hồ sơ, trạng thái tài khoản và lịch sử sử dụng dịch vụ.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter
            value={registeredRange}
            onChange={setRegisteredRange}
            defaultPreset="all"
            labelPrefix="Ngày đăng ký"
          />
          <ExportCsvButton
            tone="brand"
            filename="customers"
            headers={["Mã", "Tên", "SĐT", "Khu vực", "Trạng thái", "Chi tiêu"]}
            rows={items.map((row) => [
              row.code,
              row.name,
              row.phone,
              row.area,
              customerStatusLabel(row.status),
              String(row.spend),
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
            label="Tổng khách hàng"
            value={total}
            digits={1}
            icon="users"
            tone="brand"
            note="theo bộ lọc"
          />
        </li>
        <li>
          <KpiCard
            label="Đang hoạt động"
            value={items.filter((row) => row.status === "ACTIVE").length}
            digits={1}
            icon="check"
            tone="delivery"
            note="trên trang hiện tại"
          />
        </li>
        <li>
          <KpiCard
            label="Tạm khóa"
            value={items.filter((row) => row.status === "SUSPENDED").length}
            digits={1}
            icon="lock"
            tone="food"
            note="trên trang hiện tại"
          />
        </li>
        <li>
          <KpiCard
            label="Yêu cầu hỗ trợ"
            value={items.filter((row) => row.status === "NEEDS_SUPPORT").length}
            digits={1}
            icon="headset"
            tone="danger"
            note="trên trang hiện tại"
          />
        </li>
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField grow>
            <label
              htmlFor="customers-query"
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
                id="customers-query"
                type="search"
                autoComplete="off"
                value={filters.q}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                placeholder="Tên, mã khách hàng, số điện thoại..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Khu vực"
              icon="pin"
              value={filters.region === "ALL" ? null : filters.region}
              options={regionOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả khu vực"
              onChange={(next) => {
                void setFilters({ region: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={filters.status === "ALL" ? null : filters.status}
              options={customerStatusFilterOptions.filter(
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
          <AdminFilterField className="min-w-[12rem]">
            <DateRangePicker
              label="Ngày đăng ký"
              value={registeredRange}
              onChange={setRegisteredRange}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Dịch vụ"
              icon="categories"
              value={filters.service === "ALL" ? null : filters.service}
              options={serviceScopeOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả dịch vụ"
              onChange={(next) => {
                void setFilters({ service: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <div className="flex shrink-0 items-end">
            <button
              type="button"
              onClick={resetFilters}
              className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink ${focusRing}`}
            >
              <OpsIcon name="undo" className="size-4" />
              Đặt lại
            </button>
          </div>
        </AdminFilterToolbar>
        <div className="mt-3 text-xs leading-5 text-muted">
          Số điện thoại được che trên danh sách; thao tác nhạy cảm cần quyền ops
          phù hợp.
        </div>
      </section>
      {forbidden ? (
        <AdminForbiddenState />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách khách hàng."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="users"
          title="Không có khách hàng phù hợp"
          description="Thử đổi từ khóa, trạng thái hoặc bộ lọc."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <h2
              id="customers-table-title"
              className="text-sm font-semibold text-ink"
            >
              Tất cả khách hàng ({countFormat.format(total)} tài khoản)
            </h2>
            <p className="rounded-full bg-canvas px-3 py-1 text-xs text-muted">
              {isPending ? "Đang tải…" : `${items.length} kết quả trên trang`}
            </p>
          </div>
          <AdminTableContainer minWidth="min-w-[1180px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách khách hàng">
              <AdminTableHeader>
                <AdminTableRow>
                  {CUSTOMER_TABLE_COLUMNS.map((col) => (
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
                  <AdminTableBodyShimmer columns={CUSTOMER_COLUMN_COUNT} />
                ) : (
                  items.map((customer, index) => (
                    <AdminTableRow
                      key={customer.code}
                      className="cursor-pointer"
                      onClick={() => {
                        router.push(`/customers/${customer.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/customers/${customer.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell className="font-semibold text-brand">
                        {customer.code.slice(0, 8)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <div className="flex items-center gap-2">
                          <Avatar
                            letters={customer.initials}
                            tone={avatarTone(index)}
                          />
                          <div className="min-w-0">
                            <p className="font-medium whitespace-nowrap text-ink">
                              {customer.name}
                            </p>
                            <p className="text-xs whitespace-nowrap text-muted">
                              {"Danh bạ khách hàng"}
                            </p>
                          </div>
                        </div>
                      </AdminTableCell>
                      <AdminTableCell className="tabular-nums">
                        {customer.phone}
                      </AdminTableCell>
                      <AdminTableCell>{customer.area}</AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {customer.rides}
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {customer.food}
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {customer.delivery}
                      </AdminTableCell>
                      <AdminTableCell
                        align="right"
                        className="font-medium tabular-nums"
                      >
                        {vnd(customer.spend)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={customerStatusTone(customer.status)}>
                          {customerStatusLabel(customer.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink">{customer.time}</p>
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/customers/${customer.code}`}
                          label={`Xem khách hàng ${customer.code}`}
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
            summary={`Hiển thị ${items.length} / ${countFormat.format(total)} khách hàng`}
            label="Phân trang khách hàng"
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
