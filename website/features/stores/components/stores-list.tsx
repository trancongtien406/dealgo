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
import { useStoresFilters, useStoresQuery } from "@/features/stores/hooks";
import {
  storeKybStatusLabel,
  storeKybStatusTone,
  storeSaleStatusLabel,
  storeSaleStatusTone,
} from "@/features/stores/mappers";
import {
  storeKybOptions,
  storeLocationOptions,
  storeStatusOptions,
  useLiveCatalogCategoryOptions,
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
  STORE_COLUMN_COUNT,
  STORE_TABLE_COLUMNS,
} from "@/features/stores/constants";

export function StoresList() {
  const router = useRouter();
  const [filters, setFilters] = useStoresFilters();
  const { data, isPending, isError, error, refetch } = useStoresQuery();
  const { options: regionOptions } = useLiveRegionFilterOptions();
  const { options: categoryOptions } = useLiveCatalogCategoryOptions();
  const stores = data?.items ?? [];
  const total = data?.total ?? 0;
  const forbidden = isError && isForbiddenError(error);

  const resetFilters = () => {
    void setFilters({
      q: "",
      sale: "ALL",
      region: "ALL",
      category: "ALL",
      kyb: "ALL",
      location: "ALL",
      page: 1,
    });
  };

  const onPageSizeChange = (size: PageSize) => {
    void setFilters({ limit: size, page: 1 });
  };

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && stores.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách cửa hàng mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cửa hàng", href: "/stores" },
          { label: "Danh sách" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách cửa hàng & đối tác
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi hồ sơ kinh doanh, trạng thái bán hàng, đơn và tình trạng
            xét duyệt.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/stores/approvals" tone="brand">
            <OpsIcon name="shield" className="size-4" />
            Duyệt hồ sơ quán mới
          </PreviewLink>
          <ExportCsvButton
            tone="brand"
            filename="stores"
            headers={["Mã", "Tên", "Danh mục", "Khu vực", "Bán hàng", "KYB"]}
            rows={stores.map((row) => [
              row.code,
              row.name,
              row.category,
              row.area,
              row.sale ? storeSaleStatusLabel(row.sale) : "—",
              row.kyb ? storeKybStatusLabel(row.kyb) : "—",
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
            label="Tổng cửa hàng"
            value={total}
            note="theo bộ lọc"
            icon="store"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đang bán"
            value={
              stores.filter(
                (row) =>
                  row.sale === "ACTIVE" ||
                  row.sale === "OPEN" ||
                  row.sale === "BUSY",
              ).length
            }
            note="trên trang hiện tại"
            icon="check"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Chờ duyệt KYB"
            value={stores.filter((row) => row.kyb === "PENDING_KYB").length}
            note="trên trang hiện tại"
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Tạm ngưng"
            value={
              stores.filter(
                (row) => row.sale === "PAUSED" || row.sale === "CLOSED",
              ).length
            }
            note={"trên trang hiện tại"}
            icon="clock"
            tone="delivery"
          />
        </li>
        <li>
          <KpiCard
            label="Tạm khóa"
            value={stores.filter((row) => row.sale === "SUSPENDED").length}
            note={"trên trang hiện tại"}
            icon="close"
            tone="danger"
          />
        </li>
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField grow>
            <label
              htmlFor="stores-query"
              className="text-xs font-medium text-muted"
            >
              Tìm cửa hàng
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="stores-query"
                type="search"
                autoComplete="off"
                placeholder="Tên quán, mã cửa hàng, chủ sở hữu..."
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
              label="Trạng thái bán"
              icon="store"
              value={filters.sale === "ALL" ? null : filters.sale}
              options={storeStatusOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả trạng thái"
              onChange={(next) => {
                void setFilters({ sale: next ?? "ALL", page: 1 });
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
              label="Danh mục"
              icon="categories"
              value={filters.category === "ALL" ? null : filters.category}
              options={categoryOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả danh mục"
              onChange={(next) => {
                void setFilters({ category: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái KYB"
              icon="shield"
              value={filters.kyb === "ALL" ? null : filters.kyb}
              options={storeKybOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả"
              onChange={(next) => {
                void setFilters({ kyb: next ?? "ALL", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Vị trí quán"
              icon="pin"
              value={filters.location === "ALL" ? null : filters.location}
              options={storeLocationOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả"
              onChange={(next) => {
                void setFilters({ location: next ?? "ALL", page: 1 });
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
      ) : isError && stores.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách cửa hàng."
          onRetry={() => void refetch()}
        />
      ) : !isPending && stores.length === 0 ? (
        <AdminEmptyState
          icon="store"
          title="Không có cửa hàng phù hợp"
          description="Thử đổi từ khóa hoặc bộ lọc."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <h2
              id="stores-table-title"
              className="text-sm font-semibold text-ink"
            >
              Cửa hàng trong hệ thống ({countFormat.format(total)} cửa hàng)
            </h2>
            <Link
              href="/stores/approvals"
              className={`inline-flex items-center gap-1 rounded-md text-sm font-semibold text-brand ${focusRing}`}
            >
              Hàng đợi duyệt cửa hàng
              <OpsIcon name="arrowRight" className="size-4" />
            </Link>
          </div>
          <AdminTableContainer minWidth="min-w-[1180px]">
            <AdminTable ariaBusy={isPending} caption="Danh sách cửa hàng">
              <AdminTableHeader>
                <AdminTableRow>
                  {STORE_TABLE_COLUMNS.map((col) => (
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
                  <AdminTableBodyShimmer columns={STORE_COLUMN_COUNT} />
                ) : (
                  stores.map((store, index) => (
                    <AdminTableRow
                      key={store.code}
                      className="cursor-pointer"
                      onClick={() => {
                        router.push(`/stores/${store.code}`);
                      }}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/stores/${store.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell className="font-semibold text-brand">
                        {store.code.slice(0, 8)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <div className="flex items-center gap-2">
                          <Avatar
                            letters={store.initials}
                            tone={avatarTone(index)}
                          />
                          <div className="min-w-0">
                            <p className="font-medium whitespace-nowrap text-ink">
                              {store.name}
                            </p>
                            <p className="text-xs whitespace-nowrap text-muted">
                              Đối tác kinh doanh
                            </p>
                          </div>
                        </div>
                      </AdminTableCell>
                      <AdminTableCell>{store.category}</AdminTableCell>
                      <AdminTableCell>{store.owner}</AdminTableCell>
                      <AdminTableCell>
                        {store.locationMissing ? (
                          <StatusChip tone="danger">
                            Chưa ghim vị trí
                          </StatusChip>
                        ) : (
                          store.area
                        )}
                      </AdminTableCell>
                      <AdminTableCell align="right" className="tabular-nums">
                        {store.orders === null
                          ? "—"
                          : countFormat.format(store.orders)}
                      </AdminTableCell>
                      <AdminTableCell>
                        <RatingValue value={store.rating} />
                      </AdminTableCell>
                      <AdminTableCell>
                        {store.sale ? (
                          <StatusChip tone={storeSaleStatusTone(store.sale)}>
                            {storeSaleStatusLabel(store.sale)}
                          </StatusChip>
                        ) : (
                          <span className="text-muted">—</span>
                        )}
                      </AdminTableCell>
                      <AdminTableCell>
                        {store.kyb ? (
                          <StatusChip tone={storeKybStatusTone(store.kyb)}>
                            {storeKybStatusLabel(store.kyb)}
                          </StatusChip>
                        ) : (
                          <span className="text-muted">—</span>
                        )}
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/stores/${store.code}`}
                          label={`Xem cửa hàng ${store.code}`}
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
            summary={`Hiển thị ${stores.length} / ${countFormat.format(total)} cửa hàng`}
            label="Phân trang cửa hàng"
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
