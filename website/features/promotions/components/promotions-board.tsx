"use client";

import { useMemo, useState } from "react";
import {
  usePromotionsFilters,
  usePromotionsQuery,
} from "@/features/promotions/hooks";
import type { CampaignItem } from "@/features/promotions/api";
import {
  promotionCampaignStatusLabel,
  promotionCampaignStatusTone,
} from "@/features/promotions/mappers";
import type { PromotionCampaignStatus } from "@/features/promotions/types";
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

export function PromotionsBoard() {
  const [filters, setFilters] = usePromotionsFilters();
  const { data, isPending, isError, error, refetch } = usePromotionsQuery();

  const [selectedCode, setSelectedCode] = useState<string>("");
  const [dateRange, setDateRange] = useState<DateRangeValue | undefined>(
    undefined,
  );

  const rawItems: readonly CampaignItem[] = useMemo(
    () => data?.items ?? [],
    [data?.items],
  );
  const total = data?.total ?? 0;

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

  const runningCount = items.filter(
    (campaign) => campaign.status === "RUNNING" || campaign.status === "ACTIVE",
  ).length;

  const scheduledCount = items.filter(
    (campaign) =>
      campaign.status === "UPCOMING" || campaign.status === "SCHEDULED",
  ).length;

  const endedCount = items.filter(
    (campaign) => campaign.status === "ENDED" || campaign.status === "SENT",
  ).length;

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
            Chiến dịch khuyến mãi &amp; thông báo
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi phân phối chiến dịch thông báo đa kênh phục vụ tiếp thị và
            xúc tiến thương mại.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={handleDateRangeChange}
            defaultPreset="all"
          />
          <ExportCsvButton
            filename="notification-campaigns"
            headers={["Mã", "Tên", "Kênh", "Trạng thái", "Đã tiếp cận"]}
            rows={items.map((row) => [
              row.code,
              row.name,
              row.service,
              row.status,
              String(row.used),
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      <div className="flex items-start gap-3 rounded-2xl border border-amber-200 bg-amber-50/80 p-4 text-xs text-amber-900 shadow-xs">
        <OpsIcon
          name="alert"
          className="size-5 shrink-0 text-amber-600 mt-0.5"
        />
        <div className="space-y-1">
          <p className="font-semibold text-sm text-amber-950">
            Mô-đun Khuyến mãi đang trong chế độ thử nghiệm (Simulated Mode)
          </p>
          <p className="leading-relaxed text-amber-800">
            Dữ liệu hiện đang được ánh xạ từ Notification Campaigns
            (Push/SMS/In-app) nhằm phục vụ phát triển giao diện vận hành trước
            khi Promotion &amp; Voucher Engine độc lập được triển khai. Số liệu
            phản ánh lượt tiếp cận người dùng thực tế.
          </p>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <li>
          <KpiCard
            label="Tổng chiến dịch"
            value={total}
            note="theo bộ lọc · nguồn notifications"
            icon="receipt"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Đang chạy (trang)"
            value={runningCount}
            note="trên trang hiện tại"
            icon="play"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Lên lịch (trang)"
            value={scheduledCount}
            note="trên trang hiện tại"
            icon="clock"
            tone="food"
          />
        </li>
        <li>
          <KpiCard
            label="Đã kết thúc (trang)"
            value={endedCount}
            note="trên trang hiện tại"
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
              label="Kênh"
              value={channel}
              options={promotionChannelOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả kênh"
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
                placeholder="Mã KM, mã voucher, tên chương trình..."
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
          description="Thử đổi bộ lọc đối tượng, kênh phát hành hoặc từ khóa tìm kiếm."
          action={
            <AdminResetFilterButton
              onClick={handleResetFilters}
              label="Xóa bộ lọc"
            />
          }
        />
      ) : (
        <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(17rem,22rem)]">
          <div className="min-w-0 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 px-1">
              <h2
                id="promotions-table-title"
                className="text-sm font-semibold text-ink"
              >
                Danh sách chiến dịch
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
                            <p className="font-semibold whitespace-nowrap text-brand">
                              {campaign.code}
                            </p>
                          </AdminTableCell>
                          <AdminTableCell>
                            <p className="font-medium text-ink">
                              {campaign.name}
                            </p>
                            <p className="text-xs text-muted">
                              {campaign.condition}
                            </p>
                          </AdminTableCell>
                          <AdminTableCell>{campaign.service}</AdminTableCell>
                          <AdminTableCell className="text-muted">
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
                              {countFormat.format(campaign.used)}
                            </span>
                          </AdminTableCell>
                          <AdminTableCell className="text-muted">
                            {campaign.owner}
                          </AdminTableCell>
                          <AdminTableCell>
                            <span
                              className={
                                isSelected
                                  ? "font-semibold text-brand"
                                  : "text-muted hover:text-ink"
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
              <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex items-center justify-between gap-3">
                  <h2 className="text-sm font-semibold text-ink">
                    Chiến dịch đang xem
                  </h2>
                  <CampaignStatusChip
                    status={activeCampaign.status as PromotionCampaignStatus}
                  />
                </div>
                <p className="mt-3 text-lg font-bold text-ink">
                  {activeCampaign.name}
                </p>
                <p className="mt-1 text-xs text-muted">
                  Mã: {activeCampaign.code}
                </p>
                <dl className="mt-4 space-y-2.5 text-sm">
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="min-w-0 text-muted">Mã chiến dịch</dt>
                    <dd className="shrink-0 font-mono font-semibold text-brand">
                      {activeCampaign.code}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="min-w-0 text-muted">Đối tượng</dt>
                    <dd className="shrink-0 font-semibold text-ink">
                      {activeCampaign.service}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="min-w-0 text-muted">Ghi chú</dt>
                    <dd className="max-w-[14rem] text-right font-medium text-ink">
                      {activeCampaign.condition}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="min-w-0 text-muted">Thời gian</dt>
                    <dd className="shrink-0 font-semibold text-ink">
                      {activeCampaign.window}
                    </dd>
                  </div>
                  <div className="flex items-baseline justify-between gap-3">
                    <dt className="min-w-0 text-muted">Người phụ trách</dt>
                    <dd className="shrink-0 font-semibold text-ink">
                      {activeCampaign.owner}
                    </dd>
                  </div>
                </dl>
                <p className="mt-4 text-xs text-muted">
                  Số tiếp cận được lấy từ chiến dịch notification; đây không
                  phải dữ liệu voucher.
                </p>
              </section>
            ) : null}
            <div className="rounded-2xl border border-border bg-white p-4 shadow-sm text-xs text-muted">
              TEST_ONLY: trang này ánh xạ chiến dịch thông báo, chưa có module
              khuyến mãi/voucher độc lập.
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function CampaignStatusChip({ status }: { status: PromotionCampaignStatus }) {
  const label = promotionCampaignStatusLabel(status);
  if (status === "ENDED") {
    return (
      <span className="inline-flex items-center rounded-full bg-canvas px-2.5 py-1 text-xs font-semibold whitespace-nowrap text-muted">
        {label}
      </span>
    );
  }
  return (
    <StatusChip tone={promotionCampaignStatusTone(status)}>{label}</StatusChip>
  );
}
