"use client";

import Link from "next/link";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  focusRing,
  KpiCard,
  ListPager,
  PreviewLink,
  StatusChip,
  type PageSize,
} from "@/components/ui/admin-list-ui";
import { SearchSelect } from "@/components/ui/search-select";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import { useMemo } from "react";
import { useKycListFilters, useKycQueueQuery } from "@/features/kyc/hooks";
import {
  kycStatusFilterOptions,
  kycStatusLabel,
  kycStatusTone,
} from "@/features/kyc/mappers";
import { coercePageSize } from "@/lib/admin-pagination";
import { isForbiddenError } from "@/lib/api/errors";

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
  KYC_QUEUE_COLUMN_COUNT,
  KYC_QUEUE_TABLE_COLUMNS,
} from "@/features/kyc/constants";

export function KycQueueBoard() {
  const [filters, setFilters] = useKycListFilters();
  const { data, isPending, isError, error, refetch } = useKycQueueQuery();
  const forbidden = isError && isForbiddenError(error);
  const items = data?.items ?? [];
  const total = data?.total ?? items.length;

  const kycKpis = useMemo(() => {
    const rows = data?.items ?? [];
    return [
      {
        label: "Tổng hồ sơ",
        value: data?.total ?? rows.length,
        tone: "brand" as const,
        icon: "shield" as const,
        note: "theo bộ lọc",
      },
      {
        label: "Chờ xét duyệt",
        value: rows.filter((i) => i.status === "UNDER_REVIEW").length,
        tone: "food" as const,
        icon: "clock" as const,
        note: "trang hiện tại",
      },
      {
        label: "Cần bổ sung",
        value: rows.filter((i) => i.status === "NEEDS_MORE_INFO").length,
        tone: "danger" as const,
        icon: "alert" as const,
        note: "trang hiện tại",
      },
      {
        label: "Đã duyệt",
        value: rows.filter((i) => i.status === "APPROVED").length,
        tone: "success" as const,
        icon: "check" as const,
        note: "trang hiện tại",
      },
      {
        label: "Bị từ chối",
        value: rows.filter((i) => i.status === "REJECTED").length,
        tone: "danger" as const,
        icon: "close" as const,
        note: "trang hiện tại",
      },
    ];
  }, [data]);

  const resetFilters = () => {
    void setFilters({ status: "ALL", q: "", page: 1 });
  };

  return (
    <div className="space-y-5">
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ hàng đợi xét duyệt KYC tài xế mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài xế & Đối tác", href: "/drivers" },
          { label: "Duyệt hồ sơ KYC" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Duyệt hồ sơ KYC tài xế
          </h1>
          <p className="mt-1 text-sm text-muted">
            Kiểm tra giấy tờ, điều kiện dịch vụ và quyết định kích hoạt tài xế.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/drivers" tone="neutral">
            <OpsIcon name="arrowRight" className="size-4 rotate-180" />
            Danh sách tài xế
          </PreviewLink>
          <PreviewLink href="/settings/faqs" tone="ghost">
            <OpsIcon name="shield" className="size-4" />
            Xem FAQ quy trình
          </PreviewLink>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {kycKpis.map((kpi) => (
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
        <div className="grid gap-3 lg:grid-cols-4">
          <div className="min-w-0 lg:col-span-2">
            <label
              htmlFor="kyc-query"
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
                id="kyc-query"
                type="search"
                autoComplete="off"
                value={filters.q}
                onChange={(event) => {
                  void setFilters({ q: event.target.value, page: 1 });
                }}
                placeholder="Mã tài xế, tên, khu vực, biển số..."
                className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </div>
          <div className="min-w-0">
            <SearchSelect
              label="Trạng thái"
              icon="sliders"
              value={filters.status === "ALL" ? null : filters.status}
              options={kycStatusFilterOptions.filter((o) => o.value !== "ALL")}
              placeholder="Tất cả trạng thái"
              onChange={(next) => {
                void setFilters({
                  status: (next ?? "ALL") as typeof filters.status,
                  page: 1,
                });
              }}
            />
          </div>
          <div className="flex items-end">
            <AdminResetFilterButton onClick={resetFilters} label="Đặt lại" />
          </div>
        </div>
      </section>
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xét duyệt KYC"
          description="Tài khoản Ops hiện tại không được phân quyền xét duyệt thông tin hoặc kích hoạt tài xế."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải hàng đợi xét duyệt KYC tài xế."
          onRetry={() => void refetch()}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="driver"
          title="Không có hồ sơ KYC phù hợp"
          description="Thử đổi trạng thái hoặc từ khóa trên hàng đợi."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 px-1">
            <h2 className="text-sm font-semibold text-ink">
              Hàng đợi KYC ({items.length} hồ sơ mẫu)
            </h2>
            <p className="text-sm text-muted">Sắp xếp: Mới nhất</p>
          </div>
          <AdminTableContainer minWidth="min-w-[720px]">
            <AdminTable caption="Hàng đợi KYC">
              <AdminTableHeader>
                <AdminTableRow>
                  {KYC_QUEUE_TABLE_COLUMNS.map((col) => (
                    <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
                  ))}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer
                    columns={KYC_QUEUE_COLUMN_COUNT}
                    rows={5}
                  />
                ) : (
                  items.map((item, index) => (
                    <AdminTableRow key={item.code}>
                      <AdminTableCell>
                        <div className="flex items-center gap-3">
                          <Avatar
                            letters={item.initials}
                            tone={avatarTone(index)}
                          />
                          <div className="min-w-0">
                            <p className="font-semibold text-ink">
                              {item.name}
                            </p>
                            <p className="text-xs text-muted">{item.code}</p>
                          </div>
                        </div>
                      </AdminTableCell>
                      <AdminTableCell className="text-muted">
                        {item.area}
                      </AdminTableCell>
                      <AdminTableCell>
                        <p className="text-ink">{item.vehicleKind}</p>
                        <p className="text-xs text-muted">{item.plate}</p>
                      </AdminTableCell>
                      <AdminTableCell>
                        <StatusChip tone={kycStatusTone(item.status)}>
                          {kycStatusLabel(item.status)}
                        </StatusChip>
                      </AdminTableCell>
                      <AdminTableCell>
                        <Link
                          href={`/drivers/kyc/${item.code}`}
                          className={`text-sm font-semibold text-brand ${focusRing}`}
                        >
                          Xem
                        </Link>
                      </AdminTableCell>
                    </AdminTableRow>
                  ))
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager
            page={filters.page}
            pageSize={coercePageSize(filters.limit)}
            onPageChange={(p) => void setFilters({ page: p })}
            onPageSizeChange={(size: PageSize) =>
              void setFilters({ limit: size, page: 1 })
            }
            summary={`Hiển thị ${items.length} / ${total} hồ sơ KYC`}
            label="Phân trang KYC"
            lastPage={Math.max(
              1,
              Math.ceil(total / Math.max(1, filters.limit)),
            )}
          />
        </div>
      )}
    </div>
  );
}
