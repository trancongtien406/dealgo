"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  ExportCsvButton,
  focusRing,
  KpiCard,
  ListPager,
  PreviewButton,
  PreviewIconLink,
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
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import { type DateRangeValue } from "@/components/ui/date-picker";
import { SearchSelect } from "@/components/ui/search-select";
import { isDateWithinRange } from "@/lib/admin-date";
import { isForbiddenError } from "@/lib/api/errors";
import {
  disputePartyOptions,
  disputePriorityOptions,
  disputeStatusOptions,
  disputeTypeOptions,
} from "@/lib/admin-filter-options";
import {
  disputePriorityLabel,
  disputePriorityTone,
  disputeStatusLabel,
  disputeStatusTone,
} from "@/features/disputes/mappers";
import { useDisputesQuery } from "@/features/disputes/hooks";
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
  DISPUTE_TABLE_COLUMNS,
  DISPUTE_COLUMN_COUNT,
} from "@/features/disputes/constants";

export function DisputesList() {
  const router = useRouter();
  const [disputeType, setDisputeType] = useState<string | null>(null);
  const [party, setParty] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [priority, setPriority] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);
  const [dateRange, setDateRange] = useState<DateRangeValue>({
    from: null,
    to: null,
  });

  const { data, isPending, isError, error, refetch } = useDisputesQuery({
    page,
    limit: pageSize,
    q: searchQuery,
    status,
    priority,
    type: disputeType,
    party,
  });

  const rawItems = useMemo(() => data?.items ?? [], [data?.items]);
  const total = data?.total ?? 0;
  const forbidden = isError && isForbiddenError(error);

  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const items = useMemo(() => {
    return rawItems.filter((dispute) =>
      isDateWithinRange(dispute.createdAt, dateRange),
    );
  }, [rawItems, dateRange]);

  const highPriorityCount = items.filter(
    (dispute) => dispute.priority === "HIGH",
  ).length;

  const disputeKpis = useMemo(
    () => [
      {
        label: "Tổng khiếu nại",
        value: total,
        tone: "brand" as const,
        icon: "alert" as const,
        note: "Theo bộ lọc hiện tại",
      },
      {
        label: "Đang xử lý",
        value: items.filter(
          (dispute) =>
            dispute.status === "OPEN" || dispute.status === "INVESTIGATING",
        ).length,
        tone: "food" as const,
        icon: "clock" as const,
        note: "Trên trang hiện tại",
      },
      {
        label: "Chờ phản hồi",
        value: items.filter((dispute) => dispute.status === "AWAITING_RESPONSE")
          .length,
        tone: "delivery" as const,
        icon: "receipt" as const,
        note: "Trên trang hiện tại",
      },
      {
        label: "Đã giải quyết",
        value: items.filter((dispute) => dispute.status === "RESOLVED").length,
        tone: "success" as const,
        icon: "check" as const,
        note: "Trên trang hiện tại",
      },
      {
        label: "Ưu tiên cao",
        value: highPriorityCount,
        tone: "danger" as const,
        icon: "shield" as const,
        note: "Trên trang hiện tại",
        emphasis: true,
      },
    ],
    [items, total, highPriorityCount],
  );

  const handleDateRangeChange = (newRange: DateRangeValue) => {
    setDateRange(newRange);
    setPage(1);
  };

  const handleResetFilters = () => {
    setDisputeType(null);
    setParty(null);
    setStatus(null);
    setPriority(null);
    setSearchQuery("");
    setDateRange({ from: null, to: null });
    setPage(1);
  };

  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(event.target.value);
    setPage(1);
  };

  return (
    <div className="space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể tải danh sách khiếu nại."
          }
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Hỗ trợ & khiếu nại", href: "/disputes" },
          { label: "Danh sách khiếu nại" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Danh sách khiếu nại &amp; tranh chấp
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi, phân công và xử lý các vấn đề phát sinh trong vận hành
            DealGo.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <AdminHeaderDateFilter
            value={dateRange}
            onChange={handleDateRangeChange}
            defaultPreset="all"
          />
          <ExportCsvButton
            filename="disputes.csv"
            headers={["Mã", "Trạng thái"]}
            rows={items.map((dispute) => [dispute.code, dispute.status])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {disputeKpis.map((kpi) => (
          <li key={kpi.label}>
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              note={kpi.note}
              icon={kpi.icon}
              tone={kpi.tone}
            />
          </li>
        ))}
      </ul>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Loại khiếu nại"
              value={disputeType}
              options={disputeTypeOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả loại"
              onChange={(selectedOption) => {
                setDisputeType(selectedOption);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Bên khiếu nại"
              value={party}
              options={disputePartyOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả bên"
              onChange={(selectedOption) => {
                setParty(selectedOption);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={disputeStatusOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={(selectedOption) => {
                setStatus(selectedOption);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Mức ưu tiên"
              value={priority}
              options={disputePriorityOptions.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả ưu tiên"
              onChange={(selectedOption) => {
                setPriority(selectedOption);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="disputes-query"
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
                id="disputes-query"
                type="search"
                autoComplete="off"
                value={searchQuery}
                onChange={handleSearchChange}
                placeholder="Mã khiếu nại, mã đơn, người gửi..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton onClick={handleResetFilters} />
          </div>
        </AdminFilterToolbar>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập khiếu nại"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc giải quyết tranh chấp/khiếu nại."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể tải danh sách khiếu nại."
          }
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="shield"
          title="Không có khiếu nại phù hợp"
          description="Thử thay đổi bộ lọc mức ưu tiên, trạng thái hoặc từ khóa tìm kiếm."
          action={
            <AdminResetFilterButton
              onClick={handleResetFilters}
              label="Xóa bộ lọc"
            />
          }
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-sm font-semibold text-ink">Hàng đợi xử lý</h2>
              {highPriorityCount > 0 ? (
                <StatusChip tone="danger">
                  {countFormat.format(highPriorityCount)} yêu cầu ưu tiên cao
                </StatusChip>
              ) : (
                <span className="text-xs text-muted">
                  0 yêu cầu ưu tiên cao
                </span>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <p className="text-sm text-muted">Sắp xếp: Mới nhất</p>
            </div>
          </div>
          <AdminTableContainer>
            <AdminTable minWidth="min-w-[1180px]" ariaBusy={isPending}>
              <AdminTableHeader>
                <AdminTableRow>
                  {DISPUTE_TABLE_COLUMNS.map((col) => (
                    <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
                  ))}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer
                    columns={DISPUTE_COLUMN_COUNT}
                    rows={5}
                  />
                ) : (
                  items.map((dispute) => (
                    <AdminTableRow
                      key={dispute.code}
                      className="cursor-pointer"
                      onClick={() => router.push(`/disputes/${dispute.code}`)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/disputes/${dispute.code}`);
                        }
                      }}
                      tabIndex={0}
                    >
                      <AdminTableCell className="font-semibold text-brand">
                        {dispute.code}
                      </AdminTableCell>
                      <AdminTableCell className="text-muted">
                        {dispute.createdAt}
                      </AdminTableCell>
                      <AdminTableCell>{dispute.type}</AdminTableCell>
                      <AdminTableCell className="font-medium text-brand">
                        {dispute.relatedCode}
                      </AdminTableCell>
                      <AdminTableCell>{dispute.reporter}</AdminTableCell>
                      <AdminTableCell className="max-w-xs truncate text-muted">
                        {dispute.summary}
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={disputeStatusTone(dispute.status)}>
                          {disputeStatusLabel(dispute.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip
                          tone={disputePriorityTone(dispute.priority)}
                        >
                          {disputePriorityLabel(dispute.priority)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell className="text-muted">
                        {dispute.assignee}
                      </AdminTableCell>
                      <AdminTableCell
                        onClick={(event) => event.stopPropagation()}
                      >
                        <PreviewIconLink
                          href={`/disputes/${dispute.code}`}
                          label={`Xem khiếu nại ${dispute.code}`}
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
            onPageChange={setPage}
            onPageSizeChange={setPageSize}
            summary={`Hiển thị ${items.length} / ${countFormat.format(total)} khiếu nại`}
            label="Phân trang khiếu nại"
            lastPage={lastPage}
          />
          <p className="px-1 text-xs text-muted">
            Việc hoàn tiền, khóa tài khoản hoặc xử lý tranh chấp cần có phân
            quyền, bằng chứng và nhật ký kiểm toán.
          </p>
        </div>
      )}
    </div>
  );
}
