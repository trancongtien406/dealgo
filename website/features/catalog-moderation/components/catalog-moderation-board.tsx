"use client";

import { useState } from "react";
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
import { SearchSelect } from "@/components/ui/search-select";
import {
  catalogModerationStatusOptions,
  useLiveCatalogCategoryOptions,
} from "@/lib/admin-filter-options";
import type { ModeratedProduct } from "@/features/catalog-moderation/types";
import {
  moderationStatusLabel,
  moderationStatusTone,
} from "@/features/catalog-moderation/mappers";
import {
  useApproveCatalogItemMutation,
  useCatalogModerationFilters,
  useCatalogModerationQuery,
  useRejectCatalogItemMutation,
} from "@/features/catalog-moderation/hooks";
import { toast } from "@/components/ui/toast";
import { ApiError, isForbiddenError } from "@/lib/api/errors";

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
  CATALOG_MODERATION_COLUMN_COUNT,
  CATALOG_MODERATION_TABLE_COLUMNS,
} from "@/features/catalog-moderation/constants";

export function CatalogModerationBoard() {
  const { options: categoryOptions } = useLiveCatalogCategoryOptions();
  const [filters, setFilters] = useCatalogModerationFilters();
  const { data, isPending, isError, error, refetch } =
    useCatalogModerationQuery();
  const forbidden = isError && isForbiddenError(error);

  const approveMutation = useApproveCatalogItemMutation();
  const rejectMutation = useRejectCatalogItemMutation();

  const [selectedCode, setSelectedCode] = useState<string>("");

  const items = data?.items ?? [];
  const total = data?.total ?? 0;
  const page = filters.page;
  const pageSize = (filters.limit as PageSize) || 10;
  const category = filters.category || null;
  const modStatus = filters.status || null;
  const query = filters.q;

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);
  const pagedProducts = items;

  const countForStatus = (status: ModeratedProduct["status"]) => {
    if (modStatus === status) {
      return total;
    }
    if (modStatus && modStatus !== "ALL" && modStatus !== status) {
      return 0;
    }
    return items.filter((item) => item.status === status).length;
  };

  const moderationKpis = [
    {
      label: "Tổng sản phẩm",
      value: total,
      tone: "brand" as const,
      icon: "categories" as const,
      note: "Theo bộ lọc hiện tại",
    },
    {
      label: "Chờ duyệt",
      value: countForStatus("PENDING"),
      tone: "food" as const,
      icon: "clock" as const,
      note: "Cần xử lý",
    },
    {
      label: "Đã duyệt",
      value: countForStatus("APPROVED"),
      tone: "success" as const,
      icon: "check" as const,
      note: "Đang được phép hiển thị",
    },
    {
      label: "Bị từ chối",
      value: countForStatus("REJECTED"),
      tone: "danger" as const,
      icon: "alert" as const,
      note: "Cần sửa để gửi lại",
    },
  ];

  const selected = items.find((p) => p.code === selectedCode) ??
    items[0] ?? {
      id: "---",
      code: "---",
      name: "Chưa có sản phẩm",
      category: "---",
      store: "---",
      price: 0,
      submittedAt: "---",
      status: "PENDING" as const,
      nameReady: false,
      imageReady: false,
    };

  const actionPending = approveMutation.isPending || rejectMutation.isPending;

  const runModeration = async (action: "approve" | "reject") => {
    if (!selected.id || selected.id === "---" || actionPending) return;
    try {
      if (action === "approve") {
        await approveMutation.mutateAsync(selected.id);
        toast.success(`Đã duyệt ${selected.code}`);
      } else {
        await rejectMutation.mutateAsync(selected.id);
        toast.success(`Đã từ chối ${selected.code}`);
      }
    } catch (err) {
      toast.error(
        err instanceof ApiError
          ? err.message
          : "Không thể cập nhật kiểm duyệt.",
      );
    }
  };

  return (
    <div className="space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof ApiError
              ? error.message
              : "Không thể đồng bộ danh sách kiểm duyệt sản phẩm mới nhất."
          }
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Danh mục", href: "/catalog" },
          { label: "Kiểm duyệt sản phẩm" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Kiểm duyệt sản phẩm &amp; thực đơn
          </h1>
          <p className="mt-1 text-sm text-muted">
            Duyệt tên món, giá và hình ảnh trước khi hiển thị trên ứng dụng.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/catalog" tone="neutral">
            <OpsIcon name="arrowRight" className="size-4 rotate-180" />
            Cây danh mục
          </PreviewLink>
          <AdminHeaderDateFilter
            value={{ from: filters.from || null, to: filters.to || null }}
            onChange={(range) => {
              void setFilters({
                from: range.from ?? "",
                to: range.to ?? "",
                page: 1,
              });
            }}
            defaultPreset="all"
            labelPrefix="Ngày gửi"
          />
          <ExportCsvButton
            filename="catalog-moderation.csv"
            headers={["Mã", "Tên", "Cửa hàng", "Trạng thái"]}
            rows={items.map((item) => [
              item.code,
              item.name,
              item.store,
              item.status,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {moderationKpis.map((kpi) => (
          <li key={kpi.label} className="h-full">
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              note={"note" in kpi ? kpi.note : undefined}
              noteTone={
                kpi.tone === "food" || kpi.tone === "danger"
                  ? kpi.tone
                  : undefined
              }
              icon={kpi.icon}
              tone={kpi.tone}
            />
          </li>
        ))}
      </ul>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField grow>
            <label
              htmlFor="moderation-query"
              className="text-xs font-medium text-muted"
            >
              Tìm kiếm món / quán
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="moderation-query"
                type="search"
                autoComplete="off"
                placeholder="Tên món, mã sản phẩm, quán..."
                value={query}
                onChange={(e) => {
                  void setFilters({ q: e.target.value, page: 1 });
                }}
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>

          <AdminFilterField className="min-w-[11rem]">
            <SearchSelect
              label="Danh mục"
              icon="categories"
              value={category}
              options={categoryOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả danh mục"
              onChange={(v) => {
                void setFilters({ category: v || "", page: 1 });
              }}
            />
          </AdminFilterField>

          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={modStatus}
              options={catalogModerationStatusOptions.filter(
                (o) => o.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={(v) => {
                void setFilters({ status: v || "", page: 1 });
              }}
            />
          </AdminFilterField>

          <div className="flex shrink-0 items-end">
            <PreviewButton
              onClick={() => {
                void setFilters({
                  category: "",
                  status: "PENDING",
                  q: "",
                  from: "",
                  to: "",
                  page: 1,
                });
              }}
            >
              <OpsIcon name="undo" className="size-4" />
              Đặt lại
            </PreviewButton>
          </div>
        </AdminFilterToolbar>
      </section>
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền kiểm duyệt sản phẩm"
          description="Tài khoản Ops hiện tại không được phân quyền thực hiện kiểm duyệt thực đơn và món ăn của đối tác."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách kiểm duyệt sản phẩm."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="categories"
          title="Không tìm thấy sản phẩm cần duyệt"
          description="Không có sản phẩm nào khớp với điều kiện lọc hiện tại."
          action={
            <AdminResetFilterButton
              onClick={() => {
                void setFilters({
                  category: "",
                  status: "PENDING",
                  q: "",
                  from: "",
                  to: "",
                  page: 1,
                });
              }}
            />
          }
        />
      ) : (
        <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(18rem,22rem)]">
          <div className="min-w-0 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 px-1">
              <h2 className="text-sm font-semibold text-ink">
                Hàng chờ kiểm duyệt ({countFormat.format(total)} sản phẩm)
              </h2>
              <p className="text-sm text-muted">Lọc theo mới nhất</p>
            </div>
            <AdminTableContainer minWidth="min-w-[900px]">
              <AdminTable caption="Danh sách kiểm duyệt món ăn">
                <AdminTableHeader>
                  <AdminTableRow>
                    {CATALOG_MODERATION_TABLE_COLUMNS.map((col) => (
                      <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
                    ))}
                  </AdminTableRow>
                </AdminTableHeader>
                <AdminTableBody>
                  {isPending ? (
                    <AdminTableBodyShimmer
                      columns={CATALOG_MODERATION_COLUMN_COUNT}
                      rows={5}
                    />
                  ) : (
                    pagedProducts.map((item) => {
                      const isSelected = item.code === selected.code;
                      return (
                        <AdminTableRow
                          key={item.code}
                          onClick={() => setSelectedCode(item.code)}
                          className={`cursor-pointer ${
                            isSelected
                              ? "bg-brand/5 ring-1 ring-inset ring-brand/30"
                              : undefined
                          }`}
                        >
                          <AdminTableCell className="font-medium text-brand">
                            {item.code}
                          </AdminTableCell>
                          <AdminTableCell>
                            <p className="font-semibold text-ink">
                              {item.name}
                            </p>
                            <p className="text-xs text-muted">
                              {item.category}
                            </p>
                          </AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {item.store}
                          </AdminTableCell>
                          <AdminTableCell
                            align="right"
                            className="font-semibold tabular-nums"
                          >
                            {vnd(item.price)}
                          </AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {item.submittedAt}
                          </AdminTableCell>
                          <AdminTableCell>
                            <StatusChip
                              tone={moderationStatusTone(item.status)}
                            >
                              {moderationStatusLabel(item.status)}
                            </StatusChip>
                          </AdminTableCell>
                          <AdminTableCell>
                            <span className="text-sm font-semibold text-brand">
                              Xem
                            </span>
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
              onPageChange={(p) => void setFilters({ page: p })}
              onPageSizeChange={(ps) => void setFilters({ limit: ps, page: 1 })}
              summary={`Hiển thị ${pagedProducts.length} / ${countFormat.format(total)} sản phẩm`}
              label="Phân trang kiểm duyệt"
              lastPage={lastPage}
            />
          </div>
          <aside className="rounded-2xl border border-border bg-white p-4 shadow-sm">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-semibold text-ink">
                Xem trước sản phẩm
              </h2>
              <StatusChip tone={moderationStatusTone(selected.status)}>
                {moderationStatusLabel(selected.status)}
              </StatusChip>
            </div>
            <div
              aria-hidden="true"
              className="mt-3 grid h-36 place-items-center rounded-2xl bg-canvas text-muted"
            >
              <OpsIcon name="utensils" className="size-10" />
            </div>
            <p className="mt-3 text-xs text-muted">
              {selected.code} · {selected.store}
            </p>
            <p className="mt-1 text-xl font-bold text-ink">{selected.name}</p>
            <p className="mt-1 text-lg font-bold text-brand">
              {vnd(selected.price)}
            </p>
            <dl className="mt-4 space-y-2 text-sm">
              <div className="flex justify-between gap-3">
                <dt className="text-muted">Danh mục</dt>
                <dd className="font-medium text-ink">{selected.category}</dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-muted">Ngày gửi</dt>
                <dd className="font-medium text-ink">{selected.submittedAt}</dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-muted">Tên &amp; mô tả</dt>
                <dd className="font-medium text-ink">
                  {selected.nameReady ? "Đã cung cấp" : "Thiếu"}
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-muted">Hình ảnh</dt>
                <dd className="font-medium text-ink">
                  {selected.imageReady ? "Đã có" : "Cần kiểm tra"}
                </dd>
              </div>
            </dl>
            <div className="mt-4 rounded-xl border border-border bg-canvas/60 px-3 py-2 text-sm text-muted">
              Kiểm tra kỹ chất lượng hình ảnh, định giá món và chính sách an
              toàn thực phẩm trước khi phê duyệt niêm yết lên thực đơn.
            </div>
            {selected.status === "PENDING" && selected.id !== "---" ? (
              <div className="mt-4 flex flex-wrap gap-2">
                <PreviewButton
                  tone="danger"
                  compact
                  onClick={() => void runModeration("reject")}
                >
                  {actionPending ? "Đang xử lý…" : "Từ chối"}
                </PreviewButton>
                <PreviewButton
                  tone="brand"
                  compact
                  onClick={() => void runModeration("approve")}
                >
                  {actionPending ? "Đang xử lý…" : "Duyệt"}
                </PreviewButton>
              </div>
            ) : null}
          </aside>
        </div>
      )}
    </div>
  );
}
