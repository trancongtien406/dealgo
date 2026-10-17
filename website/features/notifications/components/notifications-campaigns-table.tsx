import React, { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  PreviewButton,
  PreviewTabs,
  countFormat,
  ListPager,
  type PageSize,
} from "@/components/ui/admin-list-ui";
import { SearchSelect } from "@/components/ui/search-select";
import { focusRing } from "@/lib/admin-format";
import {
  notificationAudienceOptions,
  notificationChannelOptions,
} from "@/lib/admin-filter-options";
import type { CampaignItem, NotificationTabKey } from "../api";
import { tabLabels } from "../mappers";
import { NotificationCampaignStatusChip } from "./notification-status-chip";
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
  AdminEmptyState,
  AdminListErrorBanner,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import {
  NOTIFICATION_TABLE_COLUMNS,
  NOTIFICATION_COLUMN_COUNT,
} from "../constants";

interface NotificationsCampaignsTableProps {
  campaigns: readonly CampaignItem[];
  total: number;
  pageSize: PageSize;
  lastPage: number;
  currentPage: number;
  selectedCampaign: CampaignItem | null;
  activeTab: NotificationTabKey;
  query: string;
  channel: string | null;
  audience: string | null;
  isPending: boolean;
  isError: boolean;
  onPageChange: (targetPage: number) => void;
  onPageSizeChange: (newSize: PageSize) => void;
  onTabChange: (newTab: NotificationTabKey) => void;
  onQueryChange: (newQuery: string) => void;
  onChannelChange: (newChannel: string | null) => void;
  onAudienceChange: (newAudience: string | null) => void;
  onResetFilters: () => void;
  onSelectCampaign: (campaignCode: string) => void;
  onReadCampaign: (campaign: CampaignItem) => void;
  refetch: () => void;
}

export function NotificationsCampaignsTable({
  campaigns,
  total,
  pageSize,
  lastPage,
  currentPage,
  selectedCampaign,
  activeTab,
  query,
  channel,
  audience,
  isPending,
  isError,
  onPageChange,
  onPageSizeChange,
  onTabChange,
  onQueryChange,
  onChannelChange,
  onAudienceChange,
  onResetFilters,
  onSelectCampaign,
  onReadCampaign,
  refetch,
}: NotificationsCampaignsTableProps) {
  const [isScheduleInfoVisible, setIsScheduleInfoVisible] = useState(false);

  return (
    <section className="min-w-0 overflow-hidden rounded-2xl border border-border bg-white shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3 px-4 pt-4">
        <div className="min-w-0">
          <h2
            id="notification-campaigns"
            className="text-base font-semibold text-ink"
          >
            Danh sách chiến dịch
          </h2>
          <p className="mt-1 text-sm text-muted">
            {countFormat.format(total)} chiến dịch phát hành
          </p>
        </div>
        <button
          type="button"
          onClick={() => setIsScheduleInfoVisible(!isScheduleInfoVisible)}
          className={`inline-flex items-center gap-1 rounded-md text-sm font-semibold text-brand hover:underline cursor-pointer ${focusRing}`}
        >
          {isScheduleInfoVisible ? "Đóng lịch" : "Lịch gửi tự động"}
          <OpsIcon name="arrowRight" className="size-4" />
        </button>
      </div>

      {isScheduleInfoVisible && (
        <div className="mx-4 mt-3 rounded-xl border border-brand/20 bg-brand/5 p-3 text-xs text-muted">
          <p className="font-semibold text-ink">
            Lịch phát hành chiến dịch tự động
          </p>
          <p className="mt-1">
            Các chiến dịch hẹn giờ được quét tự động mỗi 5 phút bởi background
            worker. Hệ thống đảm bảo chống gửi trùng và tự động giãn cách thông
            báo tránh spam người dùng.
          </p>
        </div>
      )}

      <div className="px-4 pt-3">
        <PreviewTabs
          label="Lọc chiến dịch thông báo"
          current={tabLabels[activeTab]}
          onChange={(label) => {
            const nextTab = (
              Object.keys(tabLabels) as NotificationTabKey[]
            ).find((key) => tabLabels[key] === label);
            onTabChange(nextTab ?? "ALL");
          }}
          tabs={Object.values(tabLabels)}
        />
      </div>

      <div
        role="tabpanel"
        className="grid gap-3 px-4 py-3 sm:grid-cols-[minmax(0,1.4fr)_minmax(10rem,1fr)_minmax(10rem,1fr)_auto] sm:items-end"
      >
        <div className="min-w-0">
          <label
            htmlFor="notification-query"
            className="text-xs font-medium text-muted"
          >
            Tìm kiếm chiến dịch
          </label>
          <div className="relative mt-1.5">
            <OpsIcon
              name="search"
              className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
            />
            <input
              id="notification-query"
              type="search"
              autoComplete="off"
              value={query}
              onChange={(event) => onQueryChange(event.target.value)}
              placeholder="Tìm chiến dịch, mã, đối tượng, kênh..."
              className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
            />
          </div>
        </div>

        <SearchSelect
          label="Kênh phát hành"
          value={channel}
          options={notificationChannelOptions.filter(
            (option) => option.value !== "ALL",
          )}
          placeholder="Tất cả các kênh"
          onChange={onChannelChange}
        />

        <SearchSelect
          label="Đối tượng nhận tin"
          value={audience}
          options={notificationAudienceOptions.filter(
            (option) => option.value !== "ALL",
          )}
          placeholder="Tất cả đối tượng"
          onChange={onAudienceChange}
        />

        <div className="flex shrink-0 items-end">
          <PreviewButton onClick={onResetFilters}>
            <OpsIcon name="undo" className="size-4" />
            Đặt lại
          </PreviewButton>
        </div>
      </div>

      {isError && campaigns.length === 0 ? (
        <div className="p-4">
          <AdminListErrorBanner
            message="Không thể tải danh sách chiến dịch thông báo."
            onRetry={refetch}
          />
        </div>
      ) : !isPending && campaigns.length === 0 ? (
        <div className="p-4">
          <AdminEmptyState
            icon="receipt"
            title="Không tìm thấy chiến dịch thông báo"
            description="Không tìm thấy chiến dịch thông báo nào phù hợp với bộ lọc hiện tại."
            action={
              <button
                type="button"
                onClick={onResetFilters}
                className="text-xs font-semibold text-brand hover:underline cursor-pointer"
              >
                Đặt lại bộ lọc
              </button>
            }
          />
        </div>
      ) : (
        <AdminTableContainer>
          <AdminTable
            aria-labelledby="notification-campaigns"
            minWidth="min-w-[980px]"
            ariaBusy={isPending}
          >
            <AdminTableHeader>
              <AdminTableRow>
                {NOTIFICATION_TABLE_COLUMNS.map((col) => (
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
                  columns={NOTIFICATION_COLUMN_COUNT}
                  rows={5}
                />
              ) : (
                campaigns.map((campaign) => {
                  const isSelected = campaign.code === selectedCampaign?.code;
                  return (
                    <AdminTableRow
                      key={campaign.code}
                      onClick={() => onSelectCampaign(campaign.code)}
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
                        <p className="font-medium text-ink">{campaign.title}</p>
                        <p className="text-xs text-muted line-clamp-1">
                          {campaign.body}
                        </p>
                      </AdminTableCell>
                      <AdminTableCell>{campaign.channel}</AdminTableCell>
                      <AdminTableCell className="text-muted">
                        {campaign.audience}
                      </AdminTableCell>
                      <AdminTableCell className="text-muted">
                        {campaign.schedule}
                      </AdminTableCell>
                      <AdminTableCell>
                        <NotificationCampaignStatusChip
                          status={campaign.status}
                        />
                      </AdminTableCell>
                      <AdminTableCell
                        align="right"
                        className="tabular-nums font-semibold"
                      >
                        {campaign.reached}
                      </AdminTableCell>
                      <AdminTableCell>
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            onReadCampaign(campaign);
                          }}
                          className="text-xs font-semibold text-brand hover:underline cursor-pointer"
                        >
                          Chi tiết
                        </button>
                      </AdminTableCell>
                    </AdminTableRow>
                  );
                })
              )}
            </AdminTableBody>
          </AdminTable>
        </AdminTableContainer>
      )}

      <ListPager
        page={currentPage}
        pageSize={pageSize}
        summary={`Hiển thị ${campaigns.length} / ${countFormat.format(total)} chiến dịch`}
        label="Phân trang danh sách chiến dịch"
        onPageChange={onPageChange}
        onPageSizeChange={onPageSizeChange}
        lastPage={lastPage}
      />
    </section>
  );
}
