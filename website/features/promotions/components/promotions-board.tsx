"use client";

import { useMemo, useState } from "react";
import { toast } from "sonner";
import {
  usePromotionsFilters,
  usePromotionsQuery,
} from "@/features/promotions/hooks";
import {
  updatePromotionStatus,
  type CampaignItem,
} from "@/features/promotions/api";
import {
  promotionCampaignStatusLabel,
  promotionCampaignStatusTone,
} from "@/features/promotions/mappers";
import type { PromotionCampaignStatus } from "@/features/promotions/types";
import { CreatePromotionDialog } from "./create-promotion-dialog";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  focusRing,
  KpiCard,
  ExportCsvButton,
  ListPager,
  PreviewButton,
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
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import type { DateRangeValue } from "@/components/ui/date-picker";
import { isDateWithinRange } from "@/lib/admin-date";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import {
  promotionAudienceOptions,
  promotionChannelOptions,
  promotionStatusOptions,
} from "@/lib/admin-filter-options";
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
  PROMOTION_TABLE_COLUMNS,
  PROMOTION_COLUMN_COUNT,
} from "@/features/promotions/constants";

function formatVnd(val?: number): string {
  if (val === undefined || val === null) return "0 đ";
  if (val >= 1_000_000) {
    return `${(val / 1_000_000).toFixed(1).replace(/\.0$/, "")}M đ`;
  }
  if (val >= 1_000) {
    return `${(val / 1_000).toFixed(0)}k đ`;
  }
  return `${val.toLocaleString("vi-VN")} đ`;
}

export function PromotionsBoard() {
  const [filters, setFilters] = usePromotionsFilters();
  const { data, isPending, isError, error, refetch } = usePromotionsQuery();

  const [selectedCode, setSelectedCode] = useState<string>("");
  const [dateRange, setDateRange] = useState<DateRangeValue | undefined>(
    undefined,
  );
  const [createOpen, setCreateOpen] = useState(false);
  const [updatingId, setUpdatingId] = useState<string | null>(null);

  const rawItems: readonly CampaignItem[] = useMemo(
    () => data?.items ?? [],
    [data?.items],
  );
  const total = data?.total ?? 0;
  const kpi = data?.kpi;

  const audience = filters.audience || null;
  const channel = filters.channel || null;
  const status = filters.status || null;
  const searchQuery = filters.q;
  const page = filters.page;
  const pageSize = (filters.limit as PageSize) || 10;
  const forbidden = isError && isForbiddenError(error);

  const items = useMemo(() => {
    return rawItems.filter((campaign) =>
      isDateWithinRange(campaign.window, dateRange),
    );
  }, [rawItems, dateRange]);

  const activeCampaign =
    items.find((campaign) => campaign.code === selectedCode) ?? items[0];

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const runningCount =
    kpi?.activeCount ??
    items.filter(
      (campaign) => campaign.status === "ACTIVE" || campaign.status === "RUNNING",
    ).length;

  const scheduledCount =
    kpi?.scheduledCount ??
    items.filter(
      (campaign) =>
        campaign.status === "SCHEDULED" || campaign.status === "UPCOMING",
    ).length;

  const totalCommittedBudget =
    kpi?.totalBudgetCommitted ??
    items.reduce((acc, c) => acc + (c.totalBudget || 0), 0);

  const totalUsedCount =
    kpi?.totalRedemptions ??
    items.reduce((acc, c) => acc + (c.usedCount || c.used || 0), 0);

  const errorMessage = isError
    ? error instanceof ApiError
      ? error.message
      : "Không thể tải danh sách khuyến mãi."
    : null;

  const handleDateRangeChange = (newRange: DateRangeValue | undefined) => {
    setDateRange(newRange);
    void setFilters({ page: 1 });
  };

  const handleAudienceChange = (selectedAudience: string | null) => {
    void setFilters({ audience: selectedAudience ?? "", page: 1 });
  };

  const handleChannelChange = (selectedChannel: string | null) => {
    void setFilters({ channel: selectedChannel ?? "", page: 1 });
  };

  const handleStatusChange = (selectedStatus: string | null) => {
    void setFilters({ status: selectedStatus ?? "", page: 1 });
  };

  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    void setFilters({ q: event.target.value, page: 1 });
  };

  const handleResetFilters = () => {
    void setFilters({
      audience: "",
      channel: "",
      status: "",
      q: "",
      page: 1,
    });
  };

  const handlePageChange = (targetPage: number) => {
    void setFilters({ page: targetPage });
  };

  const handlePageSizeChange = (newSize: PageSize) => {
    void setFilters({ limit: newSize, page: 1 });
  };

  const handleStatusAction = async (
    targetCampaign: CampaignItem,
    newStatus: "ACTIVE" | "PAUSED" | "CANCELLED",
  ) => {
    setUpdatingId(targetCampaign.id);
    try {
      await updatePromotionStatus(targetCampaign.id, newStatus);
      const actionName =
        newStatus === "ACTIVE"
          ? "kích hoạt"
          : newStatus === "PAUSED"
            ? "tạm dừng"
            : "hủy";
      toast.success(
        `Đã ${actionName} chiến dịch ${targetCampaign.code} thành công!`,
      );
      void refetch();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Thao tác thất bại.";
      toast.error(msg);
    } finally {
      setUpdatingId(null);
    }
  };

  return (
    <div className="min-w-0 space-y-5">
      {errorMessage && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message={errorMessage}
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tiếp thị", href: "/promotions" },
          { label: "Khuyến mãi" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Quản trị Khuyến mãi &amp; Voucher
          </h1>
          <p className="mt-1 text-sm text-muted">
            Quản lý vòng đời mã giảm giá, kiểm soát ngân sách tài trợ và giới hạn
            lượt sử dụng cho Ride và Food.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => setCreateOpen(true)}
            className="inline-flex h-9 items-center gap-2 rounded-xl bg-brand px-3.5 text-xs font-semibold text-white shadow-sm hover:bg-brand/90 transition-colors cursor-pointer"
          >
            <OpsIcon name="receipt" className="size-4" />
            Tạo voucher mới
          </button>
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={handleDateRangeChange}
            defaultPreset="all"
          />
          <ExportCsvButton
            filename="dealgo-promotions"
            headers={[
              "Mã voucher",
              "Tên chiến dịch",
              "Dịch vụ",
              "Trạng thái",
              "Đã dùng",
              "Hạn mức",
              "Ngân sách",
            ]}
            rows={items.map((row) => [
              row.code,
              row.name,
              row.service,
              row.status,
              String(row.usedCount || row.used),
              String(row.usageLimit || row.cap),
              String(row.totalBudget || 0),
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <li>
          <KpiCard
            label="Tổng chương trình"
            value={total}
            note="chiến dịch khuyến mãi trong hệ thống"
            icon="receipt"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đang hoạt động"
            value={runningCount}
            note="voucher sẵn sàng quy đổi"
            icon="play"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Lên lịch / Tạm dừng"
            value={scheduledCount}
            note="sắp diễn ra hoặc chờ điều chỉnh"
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Lượt quy đổi thực tế"
            value={totalUsedCount}
            note={`ngân sách cam kết: ${formatVnd(totalCommittedBudget)}`}
            icon="check"
            tone="delivery"
          />
        </li>
      </ul>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField>
            <SearchSelect
              label="Đối tượng"
              value={audience}
              options={promotionAudienceOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả đối tượng"
              onChange={handleAudienceChange}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Dịch vụ"
              value={channel}
              options={promotionChannelOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả dịch vụ"
              onChange={handleChannelChange}
            />
          </AdminFilterField>
          <AdminFilterField>
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={promotionStatusOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={handleStatusChange}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="promotions-search-input"
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
                id="promotions-search-input"
                type="search"
                autoComplete="off"
                placeholder="Mã voucher, tên chương trình..."
                value={searchQuery}
                onChange={handleSearchChange}
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 items-end">
            <PreviewButton onClick={handleResetFilters}>
              <OpsIcon name="undo" className="size-4" />
              Đặt lại
            </PreviewButton>
          </div>
        </AdminFilterToolbar>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập khuyến mãi"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc quản trị chiến dịch khuyến mãi."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message={errorMessage ?? "Không thể tải danh sách khuyến mãi."}
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="receipt"
          title="Không tìm thấy chiến dịch khuyến mãi"
          description="Thử đổi bộ lọc đối tượng, dịch vụ hoặc từ khóa tìm kiếm."
          action={
            <AdminResetFilterButton
              onClick={handleResetFilters}
              label="Xóa bộ lọc"
            />
          }
        />
      ) : (
        <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(19rem,24rem)]">
          <div className="min-w-0 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 px-1">
              <h2
                id="promotions-table-title"
                className="text-sm font-semibold text-ink"
              >
                Danh sách chương trình voucher
              </h2>
              <div className="flex flex-wrap items-center gap-3">
                <p className="text-sm text-muted">
                  {countFormat.format(total)} chương trình
                </p>
              </div>
            </div>
            <AdminTableContainer>
              <AdminTable
                aria-labelledby="promotions-table-title"
                minWidth="min-w-[1040px]"
                ariaBusy={isPending}
              >
                <AdminTableHeader>
                  <AdminTableRow>
                    {PROMOTION_TABLE_COLUMNS.map((col) => (
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
                      columns={PROMOTION_COLUMN_COUNT}
                      rows={5}
                    />
                  ) : (
                    items.map((campaign) => {
                      const isSelected = campaign.code === activeCampaign?.code;
                      const usedCount = campaign.usedCount ?? campaign.used ?? 0;
                      const usageLimit = campaign.usageLimit ?? campaign.cap ?? 0;
                      const usedBudget = campaign.usedBudget ?? 0;
                      const totalBudget = campaign.totalBudget ?? 0;

                      return (
                        <AdminTableRow
                          key={campaign.code}
                          onClick={() => setSelectedCode(campaign.code)}
                          className={`cursor-pointer ${
                            isSelected
                              ? "bg-brand/5 ring-1 ring-inset ring-brand/30"
                              : ""
                          }`}
                        >
                          <AdminTableCell>
                            <span className="font-mono font-bold whitespace-nowrap text-brand">
                              {campaign.code}
                            </span>
                          </AdminTableCell>
                          <AdminTableCell>
                            <p className="font-semibold text-ink">
                              {campaign.name}
                            </p>
                            <p className="text-xs text-muted">
                              {campaign.condition}
                            </p>
                          </AdminTableCell>
                          <AdminTableCell>
                            <span className="inline-flex items-center rounded-md bg-canvas px-2 py-0.5 text-xs font-medium text-ink">
                              {campaign.service}
                            </span>
                          </AdminTableCell>
                          <AdminTableCell className="text-xs text-muted">
                            {campaign.window}
                          </AdminTableCell>
                          <AdminTableCell>
                            <CampaignStatusChip
                              status={
                                campaign.status as PromotionCampaignStatus
                              }
                            />
                          </AdminTableCell>
                          <AdminTableCell
                            align="right"
                            className="tabular-nums"
                          >
                            <span className="font-semibold text-ink">
                              {countFormat.format(usedCount)}
                            </span>
                            <span className="text-xs text-muted">
                              {" "}
                              / {countFormat.format(usageLimit)}
                            </span>
                          </AdminTableCell>
                          <AdminTableCell
                            align="right"
                            className="tabular-nums text-xs"
                          >
                            <span className="font-medium text-ink">
                              {formatVnd(usedBudget)}
                            </span>
                            <span className="text-muted">
                              {" "}
                              / {formatVnd(totalBudget)}
                            </span>
                          </AdminTableCell>
                          <AdminTableCell className="text-xs text-muted">
                            {campaign.owner}
                          </AdminTableCell>
                          <AdminTableCell>
                            <span
                              className={
                                isSelected
                                  ? "font-semibold text-brand text-xs"
                                  : "text-muted hover:text-ink text-xs"
                              }
                            >
                              {isSelected ? "Đang chọn" : "Chi tiết"}
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
              summary={`Hiển thị ${items.length} / ${countFormat.format(total)} chương trình`}
              label="Phân trang chiến dịch"
              onPageChange={handlePageChange}
              onPageSizeChange={handlePageSizeChange}
              lastPage={lastPage}
            />
          </div>

          <div className="min-w-0 space-y-4">
            {activeCampaign ? (
              <section className="min-w-0 rounded-2xl border border-border bg-white p-5 shadow-sm">
                <div className="flex items-center justify-between gap-3">
                  <h2 className="text-sm font-semibold text-ink">
                    Chi tiết chiến dịch
                  </h2>
                  <CampaignStatusChip
                    status={activeCampaign.status as PromotionCampaignStatus}
                  />
                </div>

                <div className="mt-3 flex items-baseline justify-between gap-2 border-b border-border pb-3">
                  <div>
                    <p className="text-base font-bold text-ink">
                      {activeCampaign.name}
                    </p>
                    <p className="mt-0.5 font-mono text-xs font-semibold text-brand">
                      Mã: {activeCampaign.code}
                    </p>
                  </div>
                </div>

                {/* Progress Indicators */}
                <div className="mt-4 space-y-3 rounded-xl bg-canvas p-3 text-xs">
                  <div>
                    <div className="flex justify-between font-medium">
                      <span className="text-muted">Lượt đã quy đổi:</span>
                      <span className="text-ink">
                        {countFormat.format(activeCampaign.usedCount || activeCampaign.used || 0)}{" "}
                        / {countFormat.format(activeCampaign.usageLimit || activeCampaign.cap || 1)}
                      </span>
                    </div>
                    <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-border">
                      <div
                        className="h-full rounded-full bg-brand"
                        style={{
                          width: `${Math.min(
                            100,
                            Math.round(
                              ((activeCampaign.usedCount || activeCampaign.used || 0) /
                                (activeCampaign.usageLimit || activeCampaign.cap || 1)) *
                                100,
                            ),
                          )}%`,
                        }}
                      />
                    </div>
                  </div>

                  <div>
                    <div className="flex justify-between font-medium">
                      <span className="text-muted">Ngân sách đã chi:</span>
                      <span className="text-ink">
                        {formatVnd(activeCampaign.usedBudget || 0)} /{" "}
                        {formatVnd(activeCampaign.totalBudget || 10000000)}
                      </span>
                    </div>
                    <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-border">
                      <div
                        className="h-full rounded-full bg-emerald-500"
                        style={{
                          width: `${Math.min(
                            100,
                            Math.round(
                              ((activeCampaign.usedBudget || 0) /
                                (activeCampaign.totalBudget || 10000000)) *
                                100,
                            ),
                          )}%`,
                        }}
                      />
                    </div>
                  </div>
                </div>

                <dl className="mt-4 space-y-2.5 text-xs">
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Dịch vụ</dt>
                    <dd className="font-medium text-ink">{activeCampaign.service}</dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Điều kiện áp dụng</dt>
                    <dd className="max-w-[14rem] text-right font-medium text-ink">
                      {activeCampaign.condition}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Thời gian hiệu lực</dt>
                    <dd className="font-medium text-ink">{activeCampaign.window}</dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="text-muted">Nguồn tài trợ</dt>
                    <dd className="font-medium text-ink">{activeCampaign.owner}</dd>
                  </div>
                  {activeCampaign.description ? (
                    <div className="border-t border-border pt-2 text-muted leading-relaxed">
                      {activeCampaign.description}
                    </div>
                  ) : null}
                </dl>

                {/* Operations Actions */}
                <div className="mt-5 flex flex-wrap items-center gap-2 border-t border-border pt-4">
                  {activeCampaign.status === "ACTIVE" ? (
                    <button
                      type="button"
                      disabled={updatingId === activeCampaign.id}
                      onClick={() => handleStatusAction(activeCampaign, "PAUSED")}
                      className="inline-flex h-8 items-center gap-1.5 rounded-lg border border-amber-300 bg-amber-50 px-3 text-xs font-semibold text-amber-800 hover:bg-amber-100 transition-colors cursor-pointer disabled:opacity-50"
                    >
                      <OpsIcon name="clock" className="size-3.5" />
                      Tạm dừng
                    </button>
                  ) : activeCampaign.status === "PAUSED" ? (
                    <button
                      type="button"
                      disabled={updatingId === activeCampaign.id}
                      onClick={() => handleStatusAction(activeCampaign, "ACTIVE")}
                      className="inline-flex h-8 items-center gap-1.5 rounded-lg border border-emerald-300 bg-emerald-50 px-3 text-xs font-semibold text-emerald-800 hover:bg-emerald-100 transition-colors cursor-pointer disabled:opacity-50"
                    >
                      <OpsIcon name="play" className="size-3.5" />
                      Kích hoạt lại
                    </button>
                  ) : null}

                  {activeCampaign.status !== "CANCELLED" &&
                  activeCampaign.status !== "ENDED" ? (
                    <button
                      type="button"
                      disabled={updatingId === activeCampaign.id}
                      onClick={() => handleStatusAction(activeCampaign, "CANCELLED")}
                      className="inline-flex h-8 items-center gap-1.5 rounded-lg border border-rose-300 bg-rose-50 px-3 text-xs font-semibold text-rose-800 hover:bg-rose-100 transition-colors cursor-pointer disabled:opacity-50"
                    >
                      <OpsIcon name="close" className="size-3.5" />
                      Hủy chiến dịch
                    </button>
                  ) : null}
                </div>
              </section>
            ) : null}
          </div>
        </div>
      )}

      <CreatePromotionDialog
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSuccess={() => void refetch()}
      />
    </div>
  );
}

function CampaignStatusChip({ status }: { status: PromotionCampaignStatus }) {
  const label = promotionCampaignStatusLabel(status);
  if (status === "ENDED" || status === "CANCELLED") {
    return (
      <span className="inline-flex items-center rounded-full bg-canvas px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap text-muted">
        {label}
      </span>
    );
  }
  return (
    <StatusChip tone={promotionCampaignStatusTone(status)}>{label}</StatusChip>
  );
}
