"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  AdminBreadcrumb,
  PreviewTabs,
  StatusChip,
  focusRing,
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
import {
  inputClass,
  secondaryButton,
} from "@/features/integrations/components/integration-ui";
import { IssueDrawer } from "@/features/system-errors/components/issue-drawer";
import { IssueSparkline } from "@/features/system-errors/components/issue-sparkline";
import {
  useSystemErrorsFilters,
  useSystemErrorsQuery,
} from "@/features/system-errors/hooks";
import {
  ENVIRONMENT_OPTIONS,
  PERIOD_OPTIONS,
  PROJECT_TABS,
  SORT_OPTIONS,
  STATUS_OPTIONS,
  formatIssueCount,
  issueStatusLabel,
  issueStatusTone,
  levelTone,
  projectForTab,
  projectLabel,
  tabForProject,
} from "@/features/system-errors/mappers";
import type {
  IssuePeriod,
  IssueSort,
  IssueStatusFilter,
} from "@/features/system-errors/types";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";

const COLUMNS = 7;

export function SystemErrorsBoard() {
  const [filters, setFilters] = useSystemErrorsFilters();
  const { data, isPending, isFetching, isError, error, refetch } =
    useSystemErrorsQuery();
  const [search, setSearch] = useState(filters.q);
  const forbidden = isError && isForbiddenError(error);
  const notConfigured =
    isError && error instanceof ApiError && error.code === "CONFLICT";

  // Debounced so typing doesn't burn Sentry's per-token rate limit.
  useEffect(() => {
    if (search === filters.q) return;
    const t = setTimeout(() => void setFilters({ q: search, cursor: "" }), 400);
    return () => clearTimeout(t);
  }, [search, filters.q, setFilters]);

  const filtered =
    filters.environment !== "" ||
    filters.status !== "unresolved" ||
    filters.period !== "14d" ||
    filters.sort !== "date" ||
    filters.q !== "";

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Lỗi hệ thống" },
        ]}
      />
      <div className="flex min-w-0 flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Lỗi hệ thống
          </h1>
          <p className="mt-1 text-sm text-muted">
            Lỗi từ ứng dụng, backend và web do Sentry ghi nhận (cập nhật mỗi 30
            giây).
          </p>
        </div>
        <button
          type="button"
          className={secondaryButton}
          disabled={isFetching}
          onClick={() => void refetch()}
        >
          {isFetching ? "Đang tải…" : "Làm mới"}
        </button>
      </div>

      <PreviewTabs
        label="Nguồn lỗi"
        tabs={PROJECT_TABS.map((t) => t.label)}
        current={tabForProject(filters.project || null)}
        onChange={(tab) =>
          void setFilters({
            project: projectForTab(tab) ?? "",
            cursor: "",
            issue: "",
          })
        }
      />

      <AdminFilterToolbar>
        <AdminFilterField grow>
          <label className="block text-sm font-medium text-ink">
            Tìm kiếm
            <input
              type="search"
              className={inputClass}
              placeholder="Tiêu đề, culprit hoặc truy vấn Sentry"
              value={search}
              maxLength={200}
              onChange={(e) => setSearch(e.target.value)}
            />
          </label>
        </AdminFilterField>
        <AdminFilterField>
          <SearchSelect
            label="Trạng thái"
            value={filters.status}
            options={STATUS_OPTIONS.map((o) => ({
              value: o.value,
              label: o.label,
            }))}
            onChange={(v) =>
              void setFilters({
                status: (v || "unresolved") as IssueStatusFilter,
                cursor: "",
              })
            }
          />
        </AdminFilterField>
        <AdminFilterField>
          <SearchSelect
            label="Môi trường"
            value={filters.environment}
            placeholder="Mọi môi trường"
            options={ENVIRONMENT_OPTIONS}
            onChange={(v) =>
              void setFilters({ environment: v ?? "", cursor: "" })
            }
          />
        </AdminFilterField>
        <AdminFilterField>
          <SearchSelect
            label="Khoảng thời gian"
            value={filters.period}
            options={PERIOD_OPTIONS.map((o) => ({
              value: o.value,
              label: o.label,
            }))}
            onChange={(v) =>
              void setFilters({
                period: (v || "14d") as IssuePeriod,
                cursor: "",
              })
            }
          />
        </AdminFilterField>
        <AdminFilterField>
          <SearchSelect
            label="Sắp xếp"
            value={filters.sort}
            options={SORT_OPTIONS.map((o) => ({
              value: o.value,
              label: o.label,
            }))}
            onChange={(v) =>
              void setFilters({ sort: (v || "date") as IssueSort, cursor: "" })
            }
          />
        </AdminFilterField>
        {filtered ? (
          <AdminResetFilterButton
            onClick={() => {
              setSearch("");
              void setFilters({
                environment: "",
                status: "unresolved",
                period: "14d",
                sort: "date",
                q: "",
                cursor: "",
              });
            }}
          />
        ) : null}
      </AdminFilterToolbar>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem lỗi hệ thống"
          description="Cần quyền errors.read (Quản trị viên)."
        />
      ) : notConfigured ? (
        <AdminEmptyState
          icon="alert"
          title="Chưa kết nối Sentry"
          description={error.message}
          action={
            <Link
              href="/settings/sentry"
              className={`${secondaryButton} ${focusRing}`}
            >
              Cấu hình Sentry
            </Link>
          }
        />
      ) : isError ? (
        <AdminListErrorBanner
          message={
            error instanceof Error
              ? error.message
              : "Không tải được danh sách lỗi."
          }
          onRetry={() => void refetch()}
        />
      ) : (
        <>
          <AdminTableContainer>
            <AdminTable minWidth={960} ariaBusy={isFetching}>
              <AdminTableHeader>
                <AdminTableRow>
                  <AdminTableHead>Lỗi</AdminTableHead>
                  <AdminTableHead>Nguồn</AdminTableHead>
                  <AdminTableHead>Trạng thái</AdminTableHead>
                  <AdminTableHead>Xu hướng</AdminTableHead>
                  <AdminTableHead align="right">Sự kiện</AdminTableHead>
                  <AdminTableHead align="right">Người dùng</AdminTableHead>
                  <AdminTableHead>Gần nhất</AdminTableHead>
                </AdminTableRow>
              </AdminTableHeader>
              {isPending || !data ? (
                <AdminTableBodyShimmer columns={COLUMNS} rows={8} />
              ) : (
                <AdminTableBody>
                  {data.items.length === 0 ? (
                    <AdminTableRow>
                      <AdminTableCell colSpan={COLUMNS}>
                        <AdminEmptyState
                          icon="check"
                          title="Không có lỗi"
                          description="Không có lỗi nào khớp bộ lọc trong khoảng thời gian này."
                        />
                      </AdminTableCell>
                    </AdminTableRow>
                  ) : (
                    data.items.map((issue) => (
                      <AdminTableRow
                        key={issue.id}
                        clickable
                        selected={filters.issue === issue.id}
                        tabIndex={0}
                        onClick={() => void setFilters({ issue: issue.id })}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" || e.key === " ") {
                            e.preventDefault();
                            void setFilters({ issue: issue.id });
                          }
                        }}
                      >
                        <AdminTableCell wrap className="max-w-[28rem]">
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-xs text-muted">
                              {issue.shortId}
                            </span>
                            <StatusChip tone={levelTone(issue.level)}>
                              {issue.level}
                            </StatusChip>
                          </div>
                          <p
                            className="mt-1 line-clamp-2 break-words font-medium text-ink"
                            title={issue.title}
                          >
                            {issue.title}
                          </p>
                          {issue.culprit ? (
                            <p
                              className="truncate font-mono text-xs text-muted"
                              title={issue.culprit}
                            >
                              {issue.culprit}
                            </p>
                          ) : null}
                        </AdminTableCell>
                        <AdminTableCell>
                          {projectLabel(issue.project)}
                        </AdminTableCell>
                        <AdminTableCell>
                          <StatusChip tone={issueStatusTone(issue.status)} dot>
                            {issueStatusLabel(issue.status)}
                          </StatusChip>
                        </AdminTableCell>
                        <AdminTableCell>
                          <IssueSparkline values={issue.trend} />
                        </AdminTableCell>
                        <AdminTableCell align="right" className="tabular-nums">
                          {formatIssueCount(issue.count)}
                        </AdminTableCell>
                        <AdminTableCell align="right" className="tabular-nums">
                          {formatIssueCount(issue.userCount)}
                        </AdminTableCell>
                        <AdminTableCell>
                          {formatOpsDateTime(issue.lastSeen)}
                        </AdminTableCell>
                      </AdminTableRow>
                    ))
                  )}
                </AdminTableBody>
              )}
            </AdminTable>
          </AdminTableContainer>
          {data && (data.prevCursor || data.nextCursor) ? (
            <nav aria-label="Phân trang lỗi" className="flex justify-end gap-2">
              <button
                type="button"
                className={secondaryButton}
                disabled={!data.prevCursor || isFetching}
                onClick={() =>
                  void setFilters({ cursor: data.prevCursor ?? "" })
                }
              >
                Trang trước
              </button>
              <button
                type="button"
                className={secondaryButton}
                disabled={!data.nextCursor || isFetching}
                onClick={() =>
                  void setFilters({ cursor: data.nextCursor ?? "" })
                }
              >
                Trang sau
              </button>
            </nav>
          ) : null}
        </>
      )}

      {filters.issue ? (
        <IssueDrawer
          id={filters.issue}
          onClose={() => void setFilters({ issue: "" })}
        />
      ) : null}
    </div>
  );
}
