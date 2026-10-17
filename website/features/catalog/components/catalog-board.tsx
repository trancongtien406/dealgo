"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  catalogStatusLabel,
  catalogStatusTone,
} from "@/features/catalog/mappers";
import { useCatalogCategoriesQuery } from "@/features/catalog/hooks";
import type { CatalogCategory } from "@/features/catalog/types";
import { fetchCatalogModeration } from "@/features/catalog-moderation/api";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  focusRing,
  KpiCard,
  ExportCsvButton,
  ListPager,
  PreviewButton,
  PreviewLink,
  StatusChip,
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
import { SearchSelect } from "@/components/ui/search-select";
import { isForbiddenError } from "@/lib/api/errors";

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
  CATALOG_COLUMN_COUNT,
  CATALOG_SORT_OPTIONS,
  CATALOG_STATUS_OPTIONS,
  CATALOG_TABLE_COLUMNS,
} from "@/features/catalog/constants";

type ServiceFocus = "food" | "ride";

export function CatalogBoard() {
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<string | null>("STORES");
  const [status, setStatus] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);
  const [serviceFocus, setServiceFocus] = useState<ServiceFocus>("food");
  const [selectedCode, setSelectedCode] = useState<string | null>(null);
  const [foodExpanded, setFoodExpanded] = useState(true);

  const { data, isPending, isError, error, refetch } =
    useCatalogCategoriesQuery({
      page,
      limit: pageSize,
      q: query.trim() || undefined,
      sort,
      status,
    });
  const forbidden = isError && isForbiddenError(error);

  const moderationPending = useQuery({
    queryKey: ["ops", "catalog-moderation", "pending-count"],
    queryFn: () =>
      fetchCatalogModeration({ page: 1, limit: 1, status: "PENDING" }),
    staleTime: 30_000,
  });

  const pageRows = useMemo(() => data?.items ?? [], [data?.items]);
  const total = data?.total ?? 0;
  const totals = data?.totals ?? { categories: 0, stores: 0, items: 0 };
  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);
  const pendingModeration = moderationPending.data?.total ?? 0;
  const activeCount = pageRows.filter((r) => r.status === "ACTIVE").length;
  const hiddenCount = pageRows.filter((r) => r.status === "HIDDEN").length;
  const foodVisiblePct =
    totals.categories > 0
      ? Math.round((activeCount / totals.categories) * 100)
      : 100;

  const selected =
    pageRows.find((row) => row.code === selectedCode) ?? pageRows[0] ?? null;

  const resetFilters = () => {
    setQuery("");
    setSort("STORES");
    setStatus(null);
    setPage(1);
    setSelectedCode(null);
  };

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && pageRows.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ ngành hàng mới nhất từ máy chủ."
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Danh mục", href: "/catalog" },
          { label: "Quản lý danh mục" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Quản lý danh mục
          </h1>
          <p className="mt-1 max-w-3xl text-sm text-muted">
            Đặt xe (trả giá) và Đồ ăn. Theo dõi ngành hàng cửa hàng đồ ăn; thực
            đơn chi tiết do cửa hàng sở hữu.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/catalog/moderation" tone="neutral">
            <OpsIcon name="shield" className="size-4" />
            Kiểm duyệt món
          </PreviewLink>
          <PreviewLink href="/stores" tone="neutral">
            <OpsIcon name="store" className="size-4" />
            Cửa hàng
          </PreviewLink>
          <ExportCsvButton
            filename="catalog-food-categories.csv"
            headers={["Mã", "Tên", "Slug", "Cửa hàng", "Món", "Trạng thái"]}
            rows={pageRows.map((row) => [
              row.code,
              row.displayName,
              row.slug,
              String(row.storeCount),
              String(row.itemCount),
              row.status,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất danh mục
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <li>
          <KpiCard
            label="Dịch vụ chính"
            value={2}
            note="Đặt xe · Đồ ăn"
            icon="overview"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Ngành hàng đồ ăn"
            value={totals.categories}
            note={`${countFormat.format(activeCount)} đang hiển thị`}
            icon="categories"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Món gắn ngành"
            value={totals.items}
            note={`${countFormat.format(totals.stores)} cửa hàng`}
            icon="utensils"
            tone="delivery"
          />
        </li>
        <li>
          <KpiCard
            label="Chờ kiểm duyệt"
            value={pendingModeration}
            note="Hàng đợi món"
            icon="alert"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Ngành đang ẩn"
            value={hiddenCount}
            note="Không xóa dữ liệu gốc"
            icon="eye"
            tone="danger"
          />
        </li>
      </ul>

      <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(16rem,18rem)_minmax(0,1fr)]">
        <aside className="min-w-0 space-y-3 rounded-2xl border border-border bg-white p-4 shadow-sm">
          <div>
            <h2 className="text-base font-semibold text-ink">Cây dịch vụ</h2>
            <p className="mt-1 text-sm text-muted">
              Phạm vi hiện tại — không gồm giao hàng kiện / dịch vụ A–C
            </p>
          </div>

          <ul className="space-y-1">
            <li>
              <button
                type="button"
                onClick={() => {
                  setServiceFocus("ride");
                  setSelectedCode(null);
                }}
                aria-current={serviceFocus === "ride" ? "true" : undefined}
                className={`flex w-full min-w-0 items-center gap-2 rounded-xl px-3 py-2.5 text-left transition-colors ${
                  serviceFocus === "ride"
                    ? "bg-brand/10 font-medium text-brand"
                    : "text-ink hover:bg-canvas"
                } ${focusRing}`}
              >
                <OpsIcon name="car" className="size-4 shrink-0" />
                <span className="min-w-0 flex-1 truncate text-sm">Đặt xe</span>
                <span className="text-xs text-muted">—</span>
              </button>
            </li>

            <li>
              <div className="flex items-center gap-1">
                <button
                  type="button"
                  onClick={() => {
                    setServiceFocus("food");
                    setSelectedCode(null);
                    setFoodExpanded(true);
                  }}
                  aria-current={
                    serviceFocus === "food" && !selectedCode
                      ? "true"
                      : undefined
                  }
                  className={`flex min-w-0 flex-1 items-center gap-2 rounded-xl px-3 py-2.5 text-left transition-colors ${
                    serviceFocus === "food" && !selectedCode
                      ? "bg-food/10 font-medium text-food"
                      : "text-ink hover:bg-canvas"
                  } ${focusRing}`}
                >
                  <OpsIcon name="utensils" className="size-4 shrink-0" />
                  <span className="min-w-0 flex-1 truncate text-sm">Đồ ăn</span>
                  <span className="text-xs tabular-nums text-muted">
                    {countFormat.format(totals.items)}
                  </span>
                </button>
                <button
                  type="button"
                  aria-expanded={foodExpanded}
                  aria-label={foodExpanded ? "Thu gọn Đồ ăn" : "Mở Đồ ăn"}
                  onClick={() => setFoodExpanded((open) => !open)}
                  className={`grid size-9 shrink-0 place-items-center rounded-lg text-muted hover:bg-canvas ${focusRing}`}
                >
                  <OpsIcon
                    name="chevron"
                    className={`size-4 transition-transform ${foodExpanded ? "rotate-180" : ""}`}
                  />
                </button>
              </div>

              {foodExpanded ? (
                <ul className="mt-1 space-y-0.5 border-l border-border ml-4 pl-2">
                  {isPending ? (
                    <li className="px-2 py-3 text-xs text-muted">Đang tải…</li>
                  ) : pageRows.length === 0 ? (
                    <li className="px-2 py-3 text-xs text-muted">
                      Chưa có ngành hàng
                    </li>
                  ) : (
                    pageRows.map((row) => {
                      const active = selectedCode === row.code;
                      return (
                        <li key={row.code}>
                          <button
                            type="button"
                            onClick={() => {
                              setServiceFocus("food");
                              setSelectedCode(row.code);
                            }}
                            aria-current={active ? "true" : undefined}
                            className={`flex w-full min-w-0 items-center gap-2 rounded-lg px-2 py-2 text-left text-sm transition-colors ${
                              active
                                ? "bg-food/10 font-medium text-food"
                                : "text-ink hover:bg-canvas"
                            } ${focusRing}`}
                          >
                            <span className="min-w-0 flex-1 truncate">
                              {row.displayName}
                            </span>
                            <span className="shrink-0 text-xs tabular-nums text-muted">
                              {countFormat.format(row.storeCount)}
                            </span>
                          </button>
                        </li>
                      );
                    })
                  )}
                </ul>
              ) : null}
            </li>
          </ul>

          <div className="rounded-xl bg-canvas/80 p-3 text-xs leading-5 text-muted">
            Ngành hàng lấy từ hồ sơ cửa hàng. Đổi ngành trên cửa hàng — không
            tạo nhánh giả ngoài Đặt xe / Đồ ăn.
          </div>
          <PreviewLink href="/stores" tone="neutral">
            <OpsIcon name="store" className="size-4" />
            Chỉnh ngành trên cửa hàng
          </PreviewLink>
        </aside>

        <div className="min-w-0 space-y-4">
          {forbidden ? (
            <AdminForbiddenState
              title="Không có quyền truy cập danh mục sản phẩm"
              description="Tài khoản Ops hiện tại không được phân quyền quản lý ngành hàng và danh mục đồ ăn."
            />
          ) : serviceFocus === "ride" ? (
            <RideCatalogNotice />
          ) : (
            <>
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-base font-semibold text-ink">
                        {selected ? selected.displayName : "Đồ ăn"}
                      </h2>
                      <StatusChip tone="success">Đang dùng</StatusChip>
                    </div>
                    <p className="mt-1 text-sm text-muted">
                      {selected
                        ? `${selected.code} · /${selected.slug}`
                        : `FOOD · ${countFormat.format(totals.categories)} ngành hàng`}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {selected ? (
                      <PreviewLink
                        href={`/stores?q=${encodeURIComponent(selected.name)}`}
                        compact
                      >
                        <OpsIcon name="store" className="size-3.5" />
                        Cửa hàng ngành này
                      </PreviewLink>
                    ) : (
                      <PreviewLink href="/stores" compact>
                        <OpsIcon name="store" className="size-3.5" />
                        Tất cả cửa hàng
                      </PreviewLink>
                    )}
                    <PreviewLink
                      href="/catalog/moderation"
                      compact
                      tone="neutral"
                    >
                      <OpsIcon name="shield" className="size-3.5" />
                      Kiểm duyệt món
                    </PreviewLink>
                  </div>
                </div>
              </section>

              <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h2 className="text-base font-semibold text-ink">
                  {selected ? "Chi tiết ngành hàng" : "Ngành hàng con · Đồ ăn"}
                </h2>
                <p className="mt-1 text-sm text-muted">
                  Phân bố cửa hàng và món theo ngành trên hồ sơ cửa hàng.
                </p>
                <div className="mt-3">
                  <AdminFilterToolbar>
                    <AdminFilterField grow>
                      <label
                        htmlFor="catalog-query"
                        className="text-xs font-medium text-muted"
                      >
                        Tìm ngành hàng
                      </label>
                      <div className="relative mt-1.5">
                        <OpsIcon
                          name="search"
                          className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
                        />
                        <input
                          id="catalog-query"
                          type="search"
                          autoComplete="off"
                          value={query}
                          onChange={(event) => {
                            setQuery(event.target.value);
                            setPage(1);
                          }}
                          placeholder="Tìm tên hoặc mã ngành…"
                          className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
                        />
                      </div>
                    </AdminFilterField>
                    <AdminFilterField>
                      <SearchSelect
                        label="Trạng thái"
                        value={status}
                        options={CATALOG_STATUS_OPTIONS}
                        placeholder="Tất cả trạng thái"
                        onChange={(value) => {
                          setStatus(value);
                          setPage(1);
                        }}
                      />
                    </AdminFilterField>
                    <AdminFilterField>
                      <SearchSelect
                        label="Sắp xếp"
                        value={sort}
                        options={CATALOG_SORT_OPTIONS}
                        placeholder="Theo cửa hàng"
                        onChange={(value) => {
                          setSort(value ?? "STORES");
                          setPage(1);
                        }}
                      />
                    </AdminFilterField>
                    <div className="flex shrink-0 flex-wrap items-end gap-2">
                      <PreviewButton onClick={() => void refetch()}>
                        <OpsIcon name="refresh" className="size-4" />
                        Làm mới
                      </PreviewButton>
                      <AdminResetFilterButton onClick={resetFilters} />
                    </div>
                  </AdminFilterToolbar>
                </div>
              </section>

              {isError && pageRows.length === 0 ? (
                <AdminListErrorBanner
                  message="Lỗi kết nối máy chủ. Không thể tải danh sách ngành hàng đồ ăn."
                  onRetry={() => void refetch()}
                />
              ) : !isPending && pageRows.length === 0 ? (
                <AdminEmptyState
                  icon="categories"
                  title="Chưa có ngành hàng đồ ăn"
                  description="Không tìm thấy ngành hàng đồ ăn nào khớp với bộ lọc."
                  action={<AdminResetFilterButton onClick={resetFilters} />}
                />
              ) : (
                <div className="space-y-4">
                  <AdminTableContainer minWidth="min-w-[760px]">
                    <AdminTable
                      ariaBusy={isPending}
                      caption="Danh sách ngành hàng đồ ăn"
                    >
                      <AdminTableHeader>
                        <AdminTableRow>
                          {CATALOG_TABLE_COLUMNS.map((col) => (
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
                            columns={CATALOG_COLUMN_COUNT}
                            rows={6}
                          />
                        ) : (
                          pageRows.map((row, index) => (
                            <CategoryRow
                              key={row.code}
                              row={row}
                              index={(currentPage - 1) * pageSize + index + 1}
                              selected={selectedCode === row.code}
                              onSelect={() => {
                                setServiceFocus("food");
                                setSelectedCode(row.code);
                              }}
                            />
                          ))
                        )}
                      </AdminTableBody>
                    </AdminTable>
                  </AdminTableContainer>

                  <ListPager
                    page={currentPage}
                    pageSize={pageSize}
                    onPageChange={setPage}
                    onPageSizeChange={(size) => {
                      setPageSize(size);
                      setPage(1);
                    }}
                    lastPage={lastPage}
                    summary={`Hiển thị ${pageRows.length} / ${countFormat.format(total)} ngành hàng`}
                    label="Phân trang ngành hàng"
                  />
                </div>
              )}
            </>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
          <h2 className="text-base font-semibold text-ink">Quy tắc an toàn</h2>
          <ul className="mt-2 space-y-2 text-sm leading-5 text-muted">
            <li>
              Không xóa ngành khi còn cửa hàng hoặc đơn gắn ngành — chỉnh hồ sơ
              cửa hàng hoặc ẩn khỏi hiển thị duyệt.
            </li>
            <li>
              Thực đơn (nhóm món / món) thuộc cửa hàng; kiểm duyệt món tại trang
              riêng.
            </li>
            <li>
              Đặt xe không dùng danh mục món — cấu hình giá/vùng ở Khu vực &amp;
              giá và Phiên trả giá.
            </li>
          </ul>
        </section>
        <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
          <h2 className="text-base font-semibold text-ink">
            Tổng quan nhóm Đồ ăn
          </h2>
          <p className="mt-1 text-sm text-muted">
            {countFormat.format(activeCount)} /{" "}
            {countFormat.format(totals.categories)} ngành đang hiển thị
          </p>
          <div className="mt-3 h-2 overflow-hidden rounded-full bg-canvas">
            <div
              className="h-full rounded-full bg-food"
              style={{
                width: `${Math.min(100, Math.max(0, foodVisiblePct))}%`,
              }}
            />
          </div>
          <p className="mt-2 text-xs text-muted">
            {foodVisiblePct}% ngành hàng đang hiển thị ·{" "}
            {countFormat.format(pendingModeration)} món chờ kiểm duyệt
          </p>
        </section>
      </div>
    </div>
  );
}

function RideCatalogNotice() {
  return (
    <section className="rounded-2xl border border-border bg-white p-6 shadow-sm">
      <div className="flex items-start gap-3">
        <span className="grid size-11 shrink-0 place-items-center rounded-full bg-brand/10 text-brand">
          <OpsIcon name="car" className="size-5" />
        </span>
        <div className="min-w-0">
          <h2 className="text-base font-semibold text-ink">Đặt xe</h2>
          <p className="mt-1 text-sm leading-6 text-muted">
            Đặt xe dùng thương lượng giá (khách đề xuất · tài xế báo giá · khách
            chọn). Không có cây danh mục món / sản phẩm như Đồ ăn.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <PreviewLink href="/rides">
              <OpsIcon name="car" className="size-4" />
              Chuyến xe
            </PreviewLink>
            <PreviewLink href="/negotiations" tone="neutral">
              <OpsIcon name="gavel" className="size-4" />
              Phiên trả giá
            </PreviewLink>
            <PreviewLink href="/zones" tone="neutral">
              <OpsIcon name="pin" className="size-4" />
              Khu vực &amp; giá
            </PreviewLink>
          </div>
        </div>
      </div>
    </section>
  );
}

function CategoryRow({
  row,
  index,
  selected,
  onSelect,
}: {
  row: CatalogCategory;
  index: number;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <AdminTableRow
      className={`cursor-pointer ${selected ? "bg-food/5" : ""}`}
      onClick={onSelect}
    >
      <AdminTableCell className="tabular-nums text-muted">
        {index}
      </AdminTableCell>
      <AdminTableCell className="font-medium">{row.code}</AdminTableCell>
      <AdminTableCell>
        <p className="font-semibold text-ink">{row.displayName}</p>
        <p className="text-xs text-muted">/{row.slug}</p>
      </AdminTableCell>
      <AdminTableCell align="right" className="tabular-nums">
        {countFormat.format(row.itemCount)}
      </AdminTableCell>
      <AdminTableCell align="right" className="font-medium tabular-nums">
        {countFormat.format(row.storeCount)}
      </AdminTableCell>
      <AdminTableCell>
        <StatusChip tone={catalogStatusTone(row.status)}>
          {catalogStatusLabel(row.status)}
        </StatusChip>
      </AdminTableCell>
      <AdminTableCell onClick={(event) => event.stopPropagation()}>
        <PreviewLink
          href={`/stores?q=${encodeURIComponent(row.name)}`}
          compact
          tone="ghost"
        >
          Chi tiết
        </PreviewLink>
      </AdminTableCell>
    </AdminTableRow>
  );
}
