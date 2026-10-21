"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  focusRing,
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
import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import { SearchSelect } from "@/components/ui/search-select";
import { isForbiddenError } from "@/lib/api/errors";
import { useSupportTicketsQuery } from "@/features/support-tickets/hooks";
import {
  formatTicketTime,
  requesterLine,
  supportCategoryLabel,
  supportCategoryOptions,
  supportChannelOptions,
  supportPriorityLabel,
  supportPriorityTone,
  supportStatusLabel,
  supportStatusOptions,
  supportStatusTone,
} from "@/features/support-tickets/mappers";

const COLUMNS = [
  "Mã yêu cầu",
  "Tiêu đề",
  "Người gửi",
  "Nhóm",
  "Kênh",
  "Ưu tiên",
  "Trạng thái",
  "Cập nhật",
] as const;

export function SupportTicketsList() {
  const router = useRouter();
  const [status, setStatus] = useState<string | null>(null);
  const [category, setCategory] = useState<string | null>(null);
  const [channel, setChannel] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);

  const { data, isPending, isError, error, refetch } = useSupportTicketsQuery({
    page,
    limit: pageSize,
    q,
    status,
    category,
    channel,
  });
  const items = data?.items ?? [];
  const total = data?.total ?? 0;
  const forbidden = isError && isForbiddenError(error);
  const lastPage = Math.max(1, Math.ceil(total / pageSize));

  const reset = () => {
    setStatus(null);
    setCategory(null);
    setChannel(null);
    setQ("");
    setPage(1);
  };
  const open = (id: string) => router.push(`/support-tickets/${id}`);
  const errorMessage =
    error instanceof Error ? error.message : "Không thể tải danh sách yêu cầu hỗ trợ.";

  return (
    <div className="space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Hỗ trợ & khiếu nại", href: "/disputes" },
          { label: "Yêu cầu hỗ trợ" },
        ]}
      />
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
          Yêu cầu hỗ trợ
        </h1>
        <p className="mt-1 text-sm text-muted">
          Yêu cầu từ ứng dụng (khách, tài xế, chủ quán) và form hỗ trợ trên website. Mới hoạt
          động gần nhất ở trên cùng.
        </p>
      </div>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={status}
              options={supportStatusOptions}
              placeholder="Tất cả trạng thái"
              onChange={(value) => {
                setStatus(value);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[10rem]">
            <SearchSelect
              label="Nhóm vấn đề"
              value={category}
              options={supportCategoryOptions}
              placeholder="Tất cả nhóm"
              onChange={(value) => {
                setCategory(value);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[9rem]">
            <SearchSelect
              label="Kênh"
              value={channel}
              options={supportChannelOptions}
              placeholder="Tất cả kênh"
              onChange={(value) => {
                setChannel(value);
                setPage(1);
              }}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label htmlFor="support-query" className="text-xs font-medium text-muted">
              Tìm kiếm
            </label>
            <div className="relative mt-1.5">
              <OpsIcon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
              />
              <input
                id="support-query"
                type="search"
                autoComplete="off"
                value={q}
                onChange={(event) => {
                  setQ(event.target.value);
                  setPage(1);
                }}
                placeholder="Mã DG-…, tiêu đề, số điện thoại/email…"
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </AdminFilterField>
          <div className="flex shrink-0 items-end gap-2">
            <PreviewButton onClick={() => void refetch()}>
              <OpsIcon name="refresh" className="size-4" />
              Làm mới
            </PreviewButton>
            <AdminResetFilterButton onClick={reset} />
          </div>
        </AdminFilterToolbar>
      </section>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem yêu cầu hỗ trợ"
          description="Tài khoản Ops hiện tại chưa được cấp quyền vận hành."
        />
      ) : isError ? (
        <AdminListErrorBanner message={errorMessage} onRetry={() => void refetch()} />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="headset"
          title="Chưa có yêu cầu hỗ trợ phù hợp"
          description="Yêu cầu mới từ ứng dụng hoặc website sẽ xuất hiện tại đây."
          action={<AdminResetFilterButton onClick={reset} label="Xóa bộ lọc" />}
        />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer>
            <AdminTable minWidth="min-w-[1080px]" ariaBusy={isPending}>
              <AdminTableHeader>
                <AdminTableRow>
                  {COLUMNS.map((label) => (
                    <AdminTableHead key={label}>{label}</AdminTableHead>
                  ))}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer columns={COLUMNS.length} rows={5} />
                ) : (
                  items.map((ticket) => {
                    const who = requesterLine(ticket);
                    return (
                      <AdminTableRow
                        key={ticket.id}
                        className="cursor-pointer"
                        tabIndex={0}
                        onClick={() => open(ticket.id)}
                        onKeyDown={(event) => {
                          if (event.key === "Enter" || event.key === " ") {
                            event.preventDefault();
                            open(ticket.id);
                          }
                        }}
                      >
                        <AdminTableCell className="font-mono font-semibold text-brand">
                          {ticket.code}
                        </AdminTableCell>
                        <AdminTableCell>
                          <p className="max-w-[18rem] truncate font-medium text-ink">
                            {ticket.subject}
                          </p>
                          {ticket.lastMessagePreview ? (
                            <p className="max-w-[18rem] truncate text-xs text-muted">
                              {ticket.awaitingRequester ? "DealGo: " : ""}
                              {ticket.lastMessagePreview}
                            </p>
                          ) : null}
                        </AdminTableCell>
                        <AdminTableCell>
                          <p className="text-ink">{who.name}</p>
                          <p className="text-xs text-muted">{who.contact}</p>
                        </AdminTableCell>
                        <AdminTableCell>{supportCategoryLabel[ticket.category]}</AdminTableCell>
                        <AdminTableCell className="text-muted">
                          {ticket.channel === "APP" ? "Ứng dụng" : "Website"}
                        </AdminTableCell>
                        <AdminTableCell>
                          <StatusChip tone={supportPriorityTone[ticket.priority]}>
                            {supportPriorityLabel[ticket.priority]}
                          </StatusChip>
                        </AdminTableCell>
                        <AdminTableCell>
                          <StatusChip tone={supportStatusTone[ticket.status]} dot>
                            {supportStatusLabel[ticket.status]}
                          </StatusChip>
                        </AdminTableCell>
                        <AdminTableCell className="text-muted">
                          {formatTicketTime(ticket.lastMessageAt)}
                        </AdminTableCell>
                      </AdminTableRow>
                    );
                  })
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager
            summary={`${total} yêu cầu`}
            label="Phân trang yêu cầu hỗ trợ"
            page={Math.min(page, lastPage)}
            lastPage={lastPage}
            pageSize={pageSize}
            onPageChange={setPage}
            onPageSizeChange={(size) => {
              setPageSize(size);
              setPage(1);
            }}
          />
        </div>
      )}
    </div>
  );
}
