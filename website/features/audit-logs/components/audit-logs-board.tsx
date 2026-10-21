"use client";

import {
  AdminBreadcrumb,
  ExportCsvButton,
  focusRing,
  ListPager,
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
import { auditResultLabel, auditResultTone } from "@/features/settings/mappers";
import {
  useAuditLogsFilters,
  useAuditLogsQuery,
} from "@/features/audit-logs/hooks";
import type { AuditLogItem } from "@/features/audit-logs/api";
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
  AUDIT_LOG_RESULT_OPTIONS,
  AUDIT_LOG_ENTITY_OPTIONS,
  AUDIT_LOG_TABLE_COLUMNS,
  AUDIT_LOG_COLUMN_COUNT,
} from "@/features/audit-logs/constants";

export function AuditLogsBoard() {
  const [filters, setFilters] = useAuditLogsFilters();
  const { data, isPending, isError, error, refetch } = useAuditLogsQuery();

  const logs: AuditLogItem[] = data?.items ?? [];
  const total = data?.total ?? 0;
  const page = filters.page;
  const pageSize = filters.limit || 10;
  const searchQuery = filters.q;
  const resultFilter = filters.result || null;
  const entityFilter = filters.entityType || null;
  const forbidden = isError && isForbiddenError(error);

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, totalPages);

  const resetFilters = () => {
    void setFilters({
      q: "",
      result: "",
      entityType: "",
      page: 1,
    });
  };

  return (
    <div className="space-y-6">
      {isError && !forbidden && logs.length > 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể tải nhật ký kiểm toán."
          }
          onRetry={() => void refetch()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Hệ thống", href: "/settings" },
          { label: "Nhật ký kiểm toán" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Nhật ký kiểm toán (Audit Logs)
          </h1>
          <p className="mt-1 text-sm text-muted">
            Ghi nhận bất biến toàn bộ hành vi can thiệp vận hành (CAP-OPS-05),
            xử lý khiếu nại, thay đổi tham số và quản trị bảo mật.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <ExportCsvButton
            filename="dealgo-audit-logs.csv"
            headers={[
              "Mã kiểm toán",
              "Thời gian",
              "Tác nhân",
              "Hành động",
              "Đối tượng",
              "Lý do căn cứ",
              "Kết quả",
            ]}
            rows={logs.map((item) => [
              item.code,
              item.time,
              item.actor,
              item.action,
              item.target,
              item.reason,
              auditResultLabel(item.result),
            ])}
          >
            Xuất CSV
          </ExportCsvButton>
        </div>
      </div>

      {/* KPI summary cards */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-2xl border border-border bg-white p-4 shadow-xs">
          <p className="text-xs font-medium text-muted">Tổng sự kiện</p>
          <p className="mt-1 text-2xl font-bold text-ink">{total}</p>
          <span className="mt-1 inline-block text-[11px] text-muted">
            Lưu vết bất biến
          </span>
        </div>
        <div className="rounded-2xl border border-border bg-white p-4 shadow-xs">
          <p className="text-xs font-medium text-muted">Thành công (trang)</p>
          <p className="mt-1 text-2xl font-bold text-success">
            {logs.filter((log) => log.result === "SUCCESS").length}
          </p>
          <span className="mt-1 inline-block text-[11px] text-muted">
            Đã áp dụng ngay
          </span>
        </div>
        <div className="rounded-2xl border border-border bg-white p-4 shadow-xs">
          <p className="text-xs font-medium text-muted">
            Chờ phê duyệt (trang)
          </p>
          <p className="mt-1 text-2xl font-bold text-brand">
            {logs.filter((log) => log.result === "PENDING_APPROVAL").length}
          </p>
          <span className="mt-1 inline-block text-[11px] text-muted">
            Quy trình Dual-control
          </span>
        </div>
        <div className="rounded-2xl border border-border bg-white p-4 shadow-xs">
          <p className="text-xs font-medium text-muted">
            Từ chối / Vi phạm (trang)
          </p>
          <p className="mt-1 text-2xl font-bold text-danger">
            {logs.filter((log) => log.result === "REJECTED").length}
          </p>
          <span className="mt-1 inline-block text-[11px] text-muted">
            Bị chặn bởi Policy
          </span>
        </div>
      </div>

      {/* Filter toolbar */}
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <AdminFilterToolbar>
          <AdminFilterField className="min-w-[12rem]">
            <SearchSelect
              label="Kết quả xử lý"
              value={resultFilter}
              options={AUDIT_LOG_RESULT_OPTIONS.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả kết quả"
              onChange={(value) => {
                void setFilters({ result: value || "", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField className="min-w-[14rem]">
            <SearchSelect
              label="Phân hệ đối tượng"
              value={entityFilter}
              options={AUDIT_LOG_ENTITY_OPTIONS.filter(
                (option) => option.value !== "ALL",
              )}
              placeholder="Tất cả phân hệ"
              onChange={(value) => {
                void setFilters({ entityType: value || "", page: 1 });
              }}
            />
          </AdminFilterField>
          <AdminFilterField grow>
            <label
              htmlFor="audit-search"
              className="text-xs font-medium text-muted"
            >
              Tìm kiếm sự kiện
            </label>
            <input
              id="audit-search"
              type="search"
              value={searchQuery}
              onChange={(event) => {
                void setFilters({ q: event.target.value, page: 1 });
              }}
              placeholder="Tìm theo mã sự kiện, tác nhân, đối tượng hoặc căn cứ..."
              className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
            />
          </AdminFilterField>
          <div className="flex shrink-0 items-end">
            <AdminResetFilterButton label="Đặt lại" onClick={resetFilters} />
          </div>
        </AdminFilterToolbar>
      </section>

      {/* Table content - 5 states */}
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem nhật ký kiểm toán"
          description="Tài khoản Ops hiện tại không được cấp quyền AUDIT_LOG_READ theo chính sách bảo mật DealGo."
        />
      ) : isError && logs.length === 0 ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không thể tải nhật ký kiểm toán."
          }
          onRetry={() => void refetch()}
        />
      ) : !isPending && logs.length === 0 ? (
        <AdminEmptyState
          icon="shield"
          title="Không tìm thấy sự kiện kiểm toán"
          description="Không có bản ghi nhật ký kiểm toán nào phù hợp với bộ lọc hiện tại."
          action={
            <AdminResetFilterButton onClick={resetFilters} label="Xóa bộ lọc" />
          }
        />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer>
            <AdminTable minWidth="min-w-[760px]" ariaBusy={isPending}>
              <AdminTableHeader>
                <AdminTableRow>
                  {AUDIT_LOG_TABLE_COLUMNS.map((col) => (
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
                    columns={AUDIT_LOG_COLUMN_COUNT}
                    rows={6}
                  />
                ) : (
                  logs.map((log) => (
                    <AdminTableRow key={log.id}>
                      <AdminTableCell className="font-mono text-xs font-semibold text-brand">
                        {log.code}
                      </AdminTableCell>
                      <AdminTableCell className="text-xs text-muted">
                        {log.time}
                      </AdminTableCell>
                      <AdminTableCell className="font-medium">
                        {log.actor}
                      </AdminTableCell>
                      <AdminTableCell>{log.action}</AdminTableCell>
                      <AdminTableCell className="font-mono text-xs">
                        {log.target}
                      </AdminTableCell>
                      <AdminTableCell
                        className="text-xs text-muted max-w-xs truncate"
                        title={log.reason}
                      >
                        {log.reason}
                      </AdminTableCell>
                      <AdminTableCell align="right">
                        <StatusChip tone={auditResultTone(log.result)}>
                          {auditResultLabel(log.result)}
                        </StatusChip>
                      </AdminTableCell>
                    </AdminTableRow>
                  ))
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>

          <ListPager
            label="sự kiện kiểm toán"
            summary={`Hiển thị ${logs.length}/${total} sự kiện kiểm toán`}
            page={currentPage}
            lastPage={totalPages}
            pageSize={pageSize as 10}
            onPageChange={(targetPage) => void setFilters({ page: targetPage })}
          />
        </div>
      )}
    </div>
  );
}
