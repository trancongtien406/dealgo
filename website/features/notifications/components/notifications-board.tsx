"use client";

import { useMemo, useState } from "react";
import {
  PreviewButton,
  type PageSize,
  ExportCsvButton,
  AdminBreadcrumb,
} from "@/components/ui/admin-list-ui";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import type { DateRangeValue } from "@/components/ui/date-picker";
import { isDateWithinRange } from "@/lib/admin-date";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { isForbiddenError } from "@/lib/api/errors";
import {
  useNotificationsQuery,
  useCmsItemsQuery,
} from "@/features/notifications/hooks";
import type {
  CampaignItem,
  NotificationTabKey,
} from "@/features/notifications/api";
import { NotificationsKpiGrid } from "./notifications-kpi-grid";
import { NotificationsCampaignsTable } from "./notifications-campaigns-table";
import { NotificationsCmsSection } from "./notifications-cms-section";
import { NotificationsCreateModal } from "./notifications-create-modal";
import { NotificationsCampaignModal } from "./notifications-campaign-modal";

export function NotificationsBoard() {
  const [activeTab, setActiveTab] = useState<NotificationTabKey>("ALL");
  const [activeCmsTab, setActiveCmsTab] = useState("Tất cả");
  const [searchQuery, setSearchQuery] = useState("");
  const [channel, setChannel] = useState<string | null>(null);
  const [audience, setAudience] = useState<string | null>(null);
  const [dateRange, setDateRange] = useState<DateRangeValue | undefined>(
    undefined,
  );
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);
  const [selectedCampaignCode, setSelectedCampaignCode] = useState<
    string | null
  >(null);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [readingCampaign, setReadingCampaign] = useState<CampaignItem | null>(
    null,
  );

  const { data, isPending, isError, error, refetch } = useNotificationsQuery({
    page,
    limit: pageSize,
    q: searchQuery,
    channel,
    audience,
    tab: activeTab,
  });

  const forbidden = isError && isForbiddenError(error);

  const {
    data: cmsData,
    isPending: isCmsPending,
    isError: isCmsError,
    error: cmsError,
    refetch: refetchCms,
  } = useCmsItemsQuery({
    kind: activeCmsTab,
  });

  const { data: allCmsData } = useCmsItemsQuery({ kind: "Tất cả" });
  const publishedCmsCount = (allCmsData?.items ?? []).filter(
    (item) => item.status === "PUBLISHED",
  ).length;

  const counts = data?.counts ?? {
    all: 0,
    running: 0,
    sent: 0,
    pending: 0,
    draft: 0,
  };
  const rawCampaigns = useMemo(() => data?.items ?? [], [data?.items]);
  const total = data?.total ?? rawCampaigns.length;

  const campaigns = useMemo(() => {
    return rawCampaigns.filter((campaign) =>
      isDateWithinRange(campaign.schedule, dateRange),
    );
  }, [rawCampaigns, dateRange]);

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const selectedCampaign =
    campaigns.find((campaign) => campaign.code === selectedCampaignCode) ??
    campaigns[0] ??
    null;

  const handleResetFilters = () => {
    setActiveTab("ALL");
    setSearchQuery("");
    setChannel(null);
    setAudience(null);
    setDateRange(undefined);
    setPage(1);
  };

  const handleDateRangeChange = (newRange: DateRangeValue | undefined) => {
    setDateRange(newRange);
    setPage(1);
  };

  const handlePageChange = (targetPage: number) => {
    setPage(targetPage);
  };

  const handlePageSizeChange = (newSize: PageSize) => {
    setPageSize(newSize);
    setPage(1);
  };

  const handleTabChange = (newTab: NotificationTabKey) => {
    setActiveTab(newTab);
    setPage(1);
  };

  const handleQueryChange = (newQuery: string) => {
    setSearchQuery(newQuery);
    setPage(1);
  };

  const handleChannelChange = (newChannel: string | null) => {
    setChannel(newChannel);
    setPage(1);
  };

  const handleAudienceChange = (newAudience: string | null) => {
    setAudience(newAudience);
    setPage(1);
  };

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && campaigns.length > 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể tải chiến dịch thông báo."
          }
          onRetry={() => void refetch()}
        />
      ) : null}
      {isCmsError && !forbidden ? (
        <AdminListErrorBanner
          message={
            cmsError instanceof Error
              ? cmsError.message
              : "Không thể tải nội dung CMS."
          }
          onRetry={() => void refetchCms()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Thông báo & CMS", href: "/notifications" },
          { label: "Quản lý nội dung" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Thông báo hệ thống &amp; Quản lý CMS
          </h1>
          <p className="mt-1 text-sm text-muted">
            Quản trị luồng thông báo gửi người dùng và nội dung xuất bản đa nền
            tảng.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={handleDateRangeChange}
            defaultPreset="all"
          />
          <PreviewButton onClick={() => setIsCreateModalOpen(true)}>
            <OpsIcon name="plus" className="size-4 text-brand" />
            Tạo chiến dịch
          </PreviewButton>
          <ExportCsvButton
            filename="notifications"
            headers={["Mã", "Tiêu đề", "Kênh", "Đối tượng", "Trạng thái"]}
            rows={campaigns.map((campaign) => [
              campaign.code,
              campaign.title,
              campaign.channel,
              campaign.audience,
              campaign.status,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền quản lý thông báo"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc phát hành chiến dịch thông báo / CMS."
        />
      ) : (
        <>
          <NotificationsKpiGrid
            counts={counts}
            runningCount={counts.running}
            pendingCount={counts.pending}
            publishedCmsCount={publishedCmsCount}
            isPending={isPending}
            isError={isError}
          />

          <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1.6fr)_minmax(18rem,24rem)]">
            <NotificationsCampaignsTable
              campaigns={campaigns}
              total={total}
              pageSize={pageSize}
              lastPage={lastPage}
              currentPage={currentPage}
              selectedCampaign={selectedCampaign}
              activeTab={activeTab}
              query={searchQuery}
              channel={channel}
              audience={audience}
              isPending={isPending}
              isError={isError}
              onPageChange={handlePageChange}
              onPageSizeChange={handlePageSizeChange}
              onTabChange={handleTabChange}
              onQueryChange={handleQueryChange}
              onChannelChange={handleChannelChange}
              onAudienceChange={handleAudienceChange}
              onResetFilters={handleResetFilters}
              onSelectCampaign={(code) => setSelectedCampaignCode(code)}
              onReadCampaign={(campaign) => setReadingCampaign(campaign)}
              refetch={() => void refetch()}
            />

            <NotificationsCmsSection
              cmsItemsList={cmsData?.items ?? []}
              activeCmsTab={activeCmsTab}
              setActiveCmsTab={setActiveCmsTab}
              isCmsPending={isCmsPending}
              isCmsError={isCmsError}
              refetchCms={() => void refetchCms()}
            />
          </div>
        </>
      )}

      <NotificationsCreateModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
      />

      <NotificationsCampaignModal
        campaign={readingCampaign}
        onClose={() => setReadingCampaign(null)}
      />
    </div>
  );
}
