"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
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
  PreviewLink,
  RatingValue,
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
import { useDriversFilters, useDriversQuery } from "@/features/drivers/hooks";
import {
  driverActivityStatusLabel,
  driverActivityStatusTone,
  driverKycStatusLabel,
  driverKycStatusTone,
} from "@/features/drivers/mappers";
import type { DriverActivityStatus } from "@/features/drivers/types";
import {
  driverActivityOptions,
  kycStatusUiOptions,
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
  DRIVER_COLUMN_COUNT,
  DRIVER_TABLE_COLUMNS,
} from "@/features/drivers/constants";

export function DriversList() {
  const router = useRouter();
  const [filters, setFilters] = useDriversFilters();
  const { data, isPending, isError, error, refetch } = useDriversQuery();
  const { options: regionOptions } = useLiveRegionFilterOptions();
  const drivers = data?.items ?? [];
  const total = data?.total ?? 0;
  const forbidden = isError && isForbiddenError(error);

  const resetFilters = () => {
    void setFilters({
      q: "",
      service: "ALL",
      region: "ALL",
      activity: "ALL",
      kyc: "ALL",
      page: 1,
    });
  };

  const onPageSizeChange = (size: PageSize) => {
    void setFilters({ limit: size, page: 1 });
  };

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && drivers.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách tài xế mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài xế & Đối tác", href: "/drivers" },
          { label: "Danh sách" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách tài xế & đối tác
          </h1>
          <p className="mt-1 text-sm text-muted">
            Quản lý xác minh KYC, phương tiện, dịch vụ đủ điều kiện và tình
            trạng hoạt động.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/drivers/kyc" tone="brand">
            <OpsIcon name="user" className="size-4" />
            Duyệt hồ sơ KYC tài xế
          </PreviewLink>
          <ExportCsvButton
            tone="brand"
            filename="drivers"
            headers={[
              "Mã",
              "Tên",
              "Khu vực",
              "Dịch vụ",
              "Biển số",
              "KYC",
              "Hoạt động",
            ]}
            rows={drivers.map((row) => [
              row.code,
              row.name,
              row.area,
              row.service,
              row.plate,
              driverKycStatusLabel(row.kyc),
              driverActivityStatusLabel(row.activity),
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất danh sách
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <li>
          <KpiCard
            label="Tổng tài xế"
            value={total}
            digits={1}
            icon="driver"
            tone="brand"
            note="theo bộ lọc"
          />
        </li>
        <li>
          <KpiCard
            label="Đang hoạt động"
            value={
              drivers.filter((row) =>
                ["ON_TRIP", "DELIVERING", "ONLINE"].includes(row.activity),
              ).length
            }
            icon="check"
            tone="success"
            note="trên trang hiện tại"
          />
        </li>
        <li>
          <KpiCard
            label="Chờ duyệt KYC"
            value={drivers.filter((row) => row.kyc === "UNDER_REVIEW").length}
            digits={1}
            icon="clock"
            tone="food"
            note="trên trang hiện tại"
          />
        </li>
        <li>
          <KpiCard
            label="Cần xác minh lại"
            value={
              drivers.filter(
                (row) =>
                  row.kyc === "NEEDS_REVERIFY" || row.kyc === "NEEDS_MORE_INFO",
              ).length
            }
            digits={1}
            icon="shield"
            tone="delivery"
            note="Cần bổ sung hồ sơ"
          />
        </li>
        <li>
          <KpiCard
            label="Tạm khóa"
            value={drivers.filter((row) => row.activity === "SUSPENDED").length}
            digits={1}
            icon="close"
            tone="danger"
            note="Vi phạm quy chế"
          />
        </li>
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField grow>
            <label
              htmlFor="drivers-query"
              className="text-xs font-medium text-muted"
            >
              Tìm tài xế
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="drivers-query"
                type="search"
                autoComplete="off"
                placeholder="Họ tên, mã tài xế, biển số..."
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
              label="Loại dịch vụ"
              icon="categories"
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
              label="Trạng thái hoạt động"
              icon="sliders"
              value={filters.activity === "ALL" ? null : filters.activity}
              options={driverActivityOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả trạng thái"
              onChange={(next) => {
                void setFilters({ activity: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái KYC"
              icon="shield"
              value={filters.kyc === "ALL" ? null : filters.kyc}
              options={kycStatusUiOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả trạng thái"
              onChange={(next) => {
                void setFilters({ kyc: next ?? "ALL", page: 1 });
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
      </section>
      {forbidden ? (
        <AdminForbiddenState />
      ) : isError && drivers.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách tài xế."
          onRetry={() => void refetch()}
        />
      ) : !isPending && drivers.length === 0 ? (
        <AdminEmptyState
          icon="driver"
          title="Không có tài xế phù hợp"
          description="Thử đổi từ khóa hoặc bộ lọc."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <h2
              id="drivers-table-title"
              className="text-sm font-semibold text-ink"
            >
              Tài xế trong hệ thống ({countFormat.format(total)} hồ sơ)
            </h2>
            <div className="flex flex-wrap items-center gap-3">
              <Link
                href="/drivers/kyc"
                className={`inline-flex items-center gap-1 rounded-md text-sm font-semibold text-brand ${focusRing}`}
              >
                Đến hàng đợi KYC
                <OpsIcon name="arrowRight" className="size-4" />
              </Link>
            </div>
          </div>
          <AdminTableContainer minWidth="min-w-[1280px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách tài xế">
              <AdminTableHeader>
                <AdminTableRow>
                  {DRIVER_TABLE_COLUMNS.map((col) => (
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
                  <AdminTableBodyShimmer columns={DRIVER_COLUMN_COUNT} />
                ) : (
                  drivers.map((driver, index) => (
                    <AdminTableRow
                      key={driver.code}
                      className="cursor-pointer"
                      onClick={() => {
                        router.push(`/drivers/${driver.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/drivers/${driver.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell className="font-semibold text-brand">
                        {driver.code.slice(0, 8)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <div className="flex items-center gap-2">
                          <Avatar
                            letters={driver.initials}
                            tone={avatarTone(index)}
                          />
                          <div className="min-w-0">
                            <p className="font-medium whitespace-nowrap text-ink">
                              {driver.name}
                            </p>
                            <p className="text-xs whitespace-nowrap text-muted">
                              Tài xế DealGo
                            </p>
                          </div>
                        </div>
                      </AdminTableCell>
                      <AdminTableCell>{driver.area}</AdminTableCell>
                      <AdminTableCell>{driver.service}</AdminTableCell>
                      <AdminTableCell>
                        <p className="font-medium text-ink">{driver.vehicle}</p>
                        <p className="text-xs text-muted">
                          {driver.vehicleKind}
                        </p>
                      </AdminTableCell>
                      <AdminTableCell className="tabular-nums">
                        {driver.plate}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={driverKycStatusTone(driver.kyc)}>
                          {driverKycStatusLabel(driver.kyc)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <ActivityChip status={driver.activity} />
                      </AdminTableCell>
                      <AdminTableCell>
                        <RatingValue value={driver.rating} />
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {driver.trips}
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/drivers/${driver.code}`}
                          label={`Xem tài xế ${driver.code}`}
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
            summary={`Hiển thị ${drivers.length} / ${countFormat.format(total)} tài xế`}
            label="Phân trang tài xế"
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

function ActivityChip({ status }: { status: DriverActivityStatus }) {
  if (status === "OFFLINE") {
    return (
      <span className="inline-flex items-center rounded-full bg-canvas px-2.5 py-1 text-xs font-semibold whitespace-nowrap text-muted">
        {driverActivityStatusLabel(status)}
      </span>
    );
  }
  return (
    <StatusChip tone={driverActivityStatusTone(status)}>
      {driverActivityStatusLabel(status)}
    </StatusChip>
  );
}
