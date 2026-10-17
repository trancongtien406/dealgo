"use client";

import { useMemo, useState } from "react";
import {
  useCustomerActivitiesQuery,
  useCustomerDetailQuery,
} from "@/features/customers/hooks";

import {
  CUSTOMER_ACTIVITY_COLUMN_COUNT,
  CUSTOMER_ACTIVITY_TABLE_COLUMNS,
  CUSTOMER_ACTIVITY_TABS,
} from "@/features/customers/constants";
import {
  customerStatusLabel,
  customerStatusTone,
} from "@/features/customers/mappers";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  ExportCsvButton,
  focusRing,
  PreviewLink,
  StatusChip,
  vnd,
} from "@/components/ui/admin-list-ui";
import { formatOpsDate } from "@/lib/ops-time";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import {
  BackToList,
  DetailHeader,
  DetailSection,
  FieldList,
  SampleNotFound,
} from "@/components/ui/admin-detail-ui";
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

export function CustomerDetail({ code }: { code: string }) {
  const {
    data: customer,
    isPending: isCustomerPending,
    isError: isCustomerError,
    error: customerError,
    refetch: refetchCustomer,
  } = useCustomerDetailQuery(code);
  const forbidden = isCustomerError && isForbiddenError(customerError);
  const [currentTab, setCurrentTab] = useState<string>("Hoạt động gần đây");
  const [page, setPage] = useState<number>(1);

  const {
    data: activitiesPage,
    isPending: isActivityPending,
    isFetching: isActivityFetching,
  } = useCustomerActivitiesQuery(code, currentTab, page);

  const handleTabChange = (tab: string) => {
    setCurrentTab(tab);
    setPage(1);
  };

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Khách hàng", href: "/customers" },
      { label: customer?.name || code },
    ],
    [customer?.name, code],
  );

  const activities = activitiesPage?.items ?? [];
  const totalItems = activitiesPage?.total ?? activities.length;
  const limit = activitiesPage?.limit ?? 6;
  const totalPages = Math.max(1, Math.ceil(totalItems / limit));

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết khách hàng"
            description="Tài khoản của bạn không được cấp quyền xem dữ liệu cá nhân của khách hàng này."
          />
        </>
      ) : isCustomerError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết thông tin khách hàng. Vui lòng thử lại."
            onRetry={() => void refetchCustomer()}
          />
        </>
      ) : isCustomerPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết khách hàng…</span>
            <div className="h-10 w-48 rounded-xl bg-canvas" />
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-6">
              <div className="h-28 rounded-2xl bg-canvas sm:col-span-2" />
              <div className="h-28 rounded-2xl bg-canvas" />
              <div className="h-28 rounded-2xl bg-canvas" />
              <div className="h-28 rounded-2xl bg-canvas" />
              <div className="h-28 rounded-2xl bg-canvas" />
            </div>
          </div>
        </>
      ) : !customer ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy khách hàng"
          listHref="/customers"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết khách hàng"
            subtitle="Xem lịch sử tài khoản, sử dụng dịch vụ và các ghi nhận chăm sóc khách hàng."
            actions={
              <>
                <BackToList href="/customers" />
                <PreviewLink href="/exceptions" tone="ghost">
                  <OpsIcon name="alert" className="size-4" />
                  Ngoại lệ liên quan
                </PreviewLink>
                <ExportCsvButton
                  filename={`${customer.code}-${currentTab.toLowerCase().replace(/\s+/g, "-")}.csv`}
                  headers={[
                    "Thời gian",
                    "Mã",
                    "Loại",
                    "Nội dung",
                    "Giá trị",
                    "Trạng thái",
                  ]}
                  rows={activities.map((row) => [
                    row.time,
                    row.code,
                    row.kind,
                    row.summary,
                    row.value,
                    row.status,
                  ])}
                  tone="brand"
                >
                  <OpsIcon name="download" className="size-4" />
                  Xuất hoạt động
                </ExportCsvButton>
              </>
            }
          />
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-6">
            <article className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:col-span-2 xl:col-span-2">
              <div className="flex min-w-0 items-center gap-3">
                <Avatar
                  letters={customer.initials}
                  tone="bg-brand/10 text-brand"
                  large
                />
                <div className="min-w-0">
                  <p className="font-semibold text-ink">{customer.name}</p>
                  <p className="text-sm text-muted">
                    {customer.code} · {customer.area || "Toàn quốc"} · Đăng ký{" "}
                    {customer.createdAt
                      ? formatOpsDate(customer.createdAt)
                      : "Chưa cập nhật"}
                  </p>
                  <div className="mt-2 flex flex-wrap gap-2">
                    <StatusChip tone={customerStatusTone(customer.status)}>
                      {customerStatusLabel(customer.status)}
                    </StatusChip>
                    <StatusChip tone="delivery">
                      Đã xác thực điện thoại
                    </StatusChip>
                  </div>
                </div>
              </div>
            </article>
            <StatCard label="Tổng chuyến xe" value={String(customer.rides)} />
            <StatCard label="Đơn đồ ăn" value={String(customer.food)} />
            <StatCard label="Đơn giao hàng" value={String(customer.delivery)} />
            <StatCard label="Tổng chi tiêu" value={vnd(customer.spend)} />
          </div>
          <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,22rem)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="customer-account"
                title="Thông tin tài khoản"
                extra={
                  <StatusChip tone="success">Hồ sơ đã xác thực</StatusChip>
                }
              >
                <FieldList
                  rows={[
                    { label: "Mã khách hàng", value: customer.code },
                    { label: "Họ tên", value: customer.name },
                    { label: "Số điện thoại", value: customer.phone },
                    {
                      label: "Email",
                      value: customer.email || "Chưa cập nhật",
                    },
                    {
                      label: "Khu vực chính",
                      value: customer.area || "Đà Nẵng",
                    },
                    {
                      label: "Ngày đăng ký",
                      value: customer.createdAt
                        ? formatOpsDate(customer.createdAt)
                        : "Chưa cập nhật",
                    },
                    {
                      label: "Đăng nhập gần nhất",
                      value:
                        customer.lastLogin || customer.time || "Chưa cập nhật",
                    },
                    {
                      label: "Tình trạng tài khoản",
                      value: (
                        <StatusChip tone={customerStatusTone(customer.status)}>
                          {customerStatusLabel(customer.status)}
                        </StatusChip>
                      ),
                    },
                    { label: "Quyền đang sử dụng", value: "Khách hàng" },
                  ]}
                />
                <p className="mt-3 flex gap-2 rounded-xl bg-brand/5 px-3 py-3 text-sm text-muted">
                  <OpsIcon
                    name="lock"
                    className="mt-0.5 size-4 shrink-0 text-brand"
                  />
                  <span>
                    Số điện thoại và email đã che. Chỉ hiển thị thông tin đầy đủ
                    khi được cấp quyền, có lý do và ghi nhận nhật ký truy cập.
                  </span>
                </p>
              </DetailSection>
              <DetailSection id="customer-support" title="Hỗ trợ & kiểm soát">
                <FieldList
                  rows={[
                    { label: "Yêu cầu hỗ trợ đang mở", value: "0 yêu cầu" },
                    { label: "Tranh chấp chưa xử lý", value: "0 tranh chấp" },
                    { label: "Cảnh báo rủi ro", value: "Không có cảnh báo" },
                    {
                      label: "Phiên trả giá gần đây",
                      value: "Chưa có dữ liệu",
                    },
                  ]}
                />
                <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <PreviewLink href="/exceptions" tone="neutral">
                    Xem hàng đợi ngoại lệ
                  </PreviewLink>
                  <PreviewLink href="/disputes" tone="ghost">
                    Xem tranh chấp
                  </PreviewLink>
                </div>
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <section
                aria-labelledby="customer-activity"
                className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5"
              >
                <h2 id="customer-activity" className="sr-only">
                  Hoạt động gần đây
                </h2>
                <div className="min-w-0 overflow-x-auto">
                  <div
                    role="tablist"
                    aria-label="Phân loại hoạt động"
                    className="flex w-max min-w-full gap-4 border-b border-border"
                  >
                    {CUSTOMER_ACTIVITY_TABS.map((tab) => {
                      const current = tab === currentTab;
                      return (
                        <button
                          key={tab}
                          type="button"
                          role="tab"
                          aria-selected={current}
                          onClick={() => handleTabChange(tab)}
                          className={
                            current
                              ? `border-b-2 border-brand px-1 pb-2 text-sm font-semibold whitespace-nowrap text-brand cursor-pointer ${focusRing}`
                              : `border-b-2 border-transparent px-1 pb-2 text-sm whitespace-nowrap text-muted hover:text-ink hover:border-border transition-colors cursor-pointer ${focusRing}`
                          }
                        >
                          {tab}
                        </button>
                      );
                    })}
                  </div>
                </div>
                <div role="tabpanel" className="mt-4 min-w-0 space-y-4">
                  <ul className="grid grid-cols-2 gap-3 xl:grid-cols-4">
                    <Metric
                      label="Chuyến xe đã đặt"
                      value={`${customer.rides} chuyến`}
                    />
                    <Metric
                      label="Đơn đồ ăn đã đặt"
                      value={`${customer.food} đơn`}
                    />
                    <Metric
                      label="Đơn giao hoàn thành"
                      value={`${customer.delivery} đơn`}
                    />
                    <Metric label="Phiên trả giá gần nhất" value="01 phiên" />
                  </ul>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <h3 className="text-base font-semibold text-ink">
                      {currentTab}{" "}
                      <span className="text-sm font-medium text-muted">
                        ({totalItems} mục)
                      </span>
                    </h3>
                    <ExportCsvButton
                      compact
                      filename={`${customer.code}-${currentTab.toLowerCase().replace(/\s+/g, "-")}.csv`}
                      headers={[
                        "Thời gian",
                        "Mã",
                        "Loại",
                        "Nội dung",
                        "Giá trị",
                        "Trạng thái",
                      ]}
                      rows={activities.map((row) => [
                        row.time,
                        row.code,
                        row.kind,
                        row.summary,
                        row.value,
                        row.status,
                      ])}
                    >
                      <OpsIcon name="download" className="size-4" />
                      Xuất lịch sử
                    </ExportCsvButton>
                  </div>
                  <AdminTableContainer minWidth="min-w-[880px]">
                    <AdminTable caption="Hoạt động của khách hàng">
                      <AdminTableHeader>
                        <AdminTableRow>
                          {CUSTOMER_ACTIVITY_TABLE_COLUMNS.map((col) => (
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
                        {isActivityPending || isActivityFetching ? (
                          Array.from({ length: 4 }).map((_, i) => (
                            <AdminTableRow key={i} className="animate-pulse">
                              <AdminTableCell>
                                <div className="h-4 w-28 rounded bg-canvas" />
                              </AdminTableCell>
                              <AdminTableCell>
                                <div className="h-4 w-24 rounded bg-canvas" />
                              </AdminTableCell>
                              <AdminTableCell>
                                <div className="h-4 w-20 rounded bg-canvas" />
                              </AdminTableCell>
                              <AdminTableCell>
                                <div className="h-4 w-44 rounded bg-canvas" />
                              </AdminTableCell>
                              <AdminTableCell align="right">
                                <div className="ml-auto h-4 w-16 rounded bg-canvas" />
                              </AdminTableCell>
                              <AdminTableCell>
                                <div className="h-5 w-20 rounded-full bg-canvas" />
                              </AdminTableCell>
                              <AdminTableCell>
                                <div className="h-4 w-10 rounded bg-canvas" />
                              </AdminTableCell>
                            </AdminTableRow>
                          ))
                        ) : activities.length === 0 ? (
                          <AdminTableRow>
                            <AdminTableCell
                              colSpan={CUSTOMER_ACTIVITY_COLUMN_COUNT}
                              className="py-6 text-center text-sm text-muted"
                            >
                              Chưa có dữ liệu cho mục này.
                            </AdminTableCell>
                          </AdminTableRow>
                        ) : (
                          activities.map((row) => (
                            <AdminTableRow key={row.code}>
                              <AdminTableCell>{row.time}</AdminTableCell>
                              <AdminTableCell className="font-semibold text-brand">
                                {row.code}
                              </AdminTableCell>
                              <AdminTableCell>{row.kind}</AdminTableCell>
                              <AdminTableCell>{row.summary}</AdminTableCell>
                              <AdminTableCell
                                align="right"
                                className="font-medium tabular-nums"
                              >
                                {row.value}
                              </AdminTableCell>
                              <AdminTableCell>
                                <StatusChip tone={row.tone}>
                                  {row.status}
                                </StatusChip>
                              </AdminTableCell>
                              <AdminTableCell>
                                <PreviewLink
                                  href={activityHref(row.code)}
                                  compact
                                  tone="ghost"
                                  label={`Xem ${row.code}`}
                                >
                                  Xem
                                </PreviewLink>
                              </AdminTableCell>
                            </AdminTableRow>
                          ))
                        )}
                      </AdminTableBody>
                    </AdminTable>
                  </AdminTableContainer>
                  <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-muted">
                    <p>
                      Hiển thị trang {page}/{totalPages} · Tổng cộng{" "}
                      {totalItems} hoạt động theo bộ lọc.
                    </p>
                    <ActivityPager
                      page={page}
                      totalPages={totalPages}
                      onPageChange={setPage}
                    />
                  </div>
                </div>
              </section>
              <DetailSection
                id="customer-note"
                title="Lưu ý cho quản trị viên"
                extra={
                  <StatusChip tone="delivery">
                    Quyền truy cập được kiểm soát
                  </StatusChip>
                }
              >
                <p className="text-sm leading-6 text-muted">
                  Phiên trả giá PTG-240610-0182 có ngân sách đề xuất 350.000đ,
                  chưa phải khoản thanh toán. Mọi tác động đến tài khoản và yêu
                  cầu cung cấp dữ liệu cá nhân đều phải được cấp quyền và lưu
                  nhật ký.
                </p>
              </DetailSection>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function activityHref(code: string): string {
  if (code.startsWith("DGX-")) return `/rides/${code}`;
  if (code.startsWith("FA-")) return `/food-orders/${code}`;
  if (code.startsWith("GH-")) return `/deliveries/${code}`;
  if (code.startsWith("PTG-")) return `/negotiations/${code}`;
  if (code.startsWith("TXN-")) return `/transactions`;
  if (code.startsWith("LOG-")) return `/settings/audit-logs`;
  return "/exceptions";
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <article className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
      <p className="text-sm text-muted">{label}</p>
      <p className="mt-2 text-2xl font-bold tracking-tight text-ink tabular-nums">
        {value}
      </p>
      <p className="mt-1 text-xs text-muted">Trong lịch sử tài khoản</p>
    </article>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <li className="min-w-0 rounded-xl bg-canvas px-3 py-3">
      <p className="text-xs text-muted">{label}</p>
      <p className="mt-1 text-lg font-bold text-ink tabular-nums">{value}</p>
    </li>
  );
}

function ActivityPager({
  page,
  totalPages,
  onPageChange,
}: {
  page: number;
  totalPages: number;
  onPageChange: (newPage: number) => void;
}) {
  if (totalPages <= 1) return null;

  return (
    <nav aria-label="Phân trang hoạt động">
      <ol className="flex items-center gap-1">
        <li>
          <button
            type="button"
            disabled={page <= 1}
            onClick={() => onPageChange(page - 1)}
            aria-label="Trang trước"
            className={`grid size-8 place-items-center rounded-lg text-sm text-ink transition-colors disabled:opacity-40 disabled:cursor-not-allowed hover:bg-canvas cursor-pointer ${focusRing}`}
          >
            <OpsIcon name="chevron" className="size-4 rotate-90" />
          </button>
        </li>
        {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => {
          const active = p === page;
          return (
            <li key={p}>
              <button
                type="button"
                onClick={() => onPageChange(p)}
                aria-current={active ? "page" : undefined}
                className={
                  active
                    ? `grid size-8 place-items-center rounded-lg bg-brand text-sm font-semibold text-white ${focusRing}`
                    : `grid size-8 place-items-center rounded-lg text-sm text-ink transition-colors hover:bg-canvas cursor-pointer ${focusRing}`
                }
              >
                {p}
              </button>
            </li>
          );
        })}
        <li>
          <button
            type="button"
            disabled={page >= totalPages}
            onClick={() => onPageChange(page + 1)}
            aria-label="Trang sau"
            className={`grid size-8 place-items-center rounded-lg text-sm text-ink transition-colors disabled:opacity-40 disabled:cursor-not-allowed hover:bg-canvas cursor-pointer ${focusRing}`}
          >
            <OpsIcon name="chevron" className="size-4 -rotate-90" />
          </button>
        </li>
      </ol>
    </nav>
  );
}
