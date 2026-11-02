"use client";

import { useMemo, useState } from "react";
import { useDriverActivitiesQuery, useDriverDetailQuery } from "@/features/drivers/hooks";
import {
  completionRateLabel,
  driverActivityStatusLabel,
  driverActivityStatusTone,
  driverKycStatusLabel,
  driverKycStatusTone,
} from "@/features/drivers/mappers";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { AccountDeletionCard } from "@/features/account-deletion/components/account-deletion-card";
import { DriverFeeCard } from "@/features/account-deletion/components/driver-fee-card";
import {
  AdminBreadcrumb,
  Avatar,
  ExportCsvButton,
  focusRing,
  PreviewLink,
  StatusChip,
  vnd,
} from "@/components/ui/admin-list-ui";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
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
import { formatOpsDate } from "@/lib/ops-time";
import {
  BackToList,
  DetailHeader,
  DetailSection,
  FieldList,
  SampleNotFound,
} from "@/components/ui/admin-detail-ui";
import { isForbiddenError } from "@/lib/api/errors";

const DRIVER_ACTIVITY_TABS = ["Tất cả", "Chuyến xe", "Giao đồ ăn", "Thu nhập"];

function EmptyPanel({ message = "Chưa có dữ liệu" }: { message?: string }) {
  return (
    <p className="rounded-xl border border-dashed border-border bg-canvas/40 px-3 py-6 text-center text-sm text-muted">
      {message}
    </p>
  );
}

export function DriverDetail({ code }: { code: string }) {
  const {
    data: driver,
    isPending,
    isError,
    error,
    refetch,
  } = useDriverDetailQuery(code);
  const forbidden = isError && isForbiddenError(error);

  const [currentTab, setCurrentTab] = useState<string>("Tất cả");
  const [page, setPage] = useState<number>(1);
  const { data: activitiesPage, isPending: isActivitiesPending } =
    useDriverActivitiesQuery(code, currentTab, page);

  const activities = activitiesPage?.items ?? [];
  const totalItems = activitiesPage?.total ?? activities.length;
  const limit = activitiesPage?.limit ?? 6;
  const totalPages = Math.max(1, Math.ceil(totalItems / limit));

  const handleTabChange = (tab: string) => {
    setCurrentTab(tab);
    setPage(1);
  };

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Tài xế & Đối tác", href: "/drivers" },
      { label: driver?.name || code },
    ],
    [driver?.name, code],
  );

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết tài xế"
            description="Tài khoản của bạn không được cấp quyền xem thông tin hồ sơ tài xế này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết thông tin tài xế. Vui lòng thử lại."
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết tài xế…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !driver ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy tài xế"
          listHref="/drivers"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết tài xế & đối tác"
            subtitle="Hồ sơ, xác minh, phương tiện và hoạt động theo quyền quản trị."
            actions={
              <>
                <BackToList href="/drivers" />
                <PreviewLink href="/exceptions" tone="ghost">
                  <OpsIcon name="alert" className="size-4" />
                  Ngoại lệ
                </PreviewLink>
                <PreviewLink href="/drivers/kyc" tone="brand">
                  Hàng đợi KYC
                  <OpsIcon name="arrowRight" className="size-4" />
                </PreviewLink>
              </>
            }
          />
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <article className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:col-span-2 xl:col-span-1">
              <div className="flex min-w-0 items-center gap-3">
                <Avatar
                  letters={driver.initials}
                  tone="bg-brand/10 text-brand"
                  large
                />
                <div className="min-w-0">
                  <p className="font-semibold text-ink">{driver.name}</p>
                  <p className="text-sm break-words text-muted">
                    {driver.code} · Đối tác tài xế
                  </p>
                </div>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                {driver.activity === "OFFLINE" ? (
                  <span className="inline-flex items-center rounded-full bg-canvas px-2.5 py-1 text-xs font-semibold text-muted">
                    {driverActivityStatusLabel(driver.activity)}
                  </span>
                ) : (
                  <StatusChip
                    tone={driverActivityStatusTone(driver.activity)}
                    dot
                  >
                    {driverActivityStatusLabel(driver.activity)}
                  </StatusChip>
                )}
                <StatusChip tone={driverKycStatusTone(driver.kyc)}>
                  {driverKycStatusLabel(driver.kyc)}
                </StatusChip>
              </div>
              <p className="mt-3 text-sm text-muted">
                {driver.rating != null
                  ? String(driver.rating).replace(".", ",")
                  : "—"}{" "}
                ({driver.trips ?? "—"} chuyến/đơn) · {driver.area}
              </p>
            </article>
            <MetricCard
              icon="categories"
              tone="bg-brand/10 text-brand"
              label="Chuyến / đơn đã nhận"
              value={driver.trips == null ? "—" : String(driver.trips)}
              hint={
                driver.trips == null
                  ? "Chưa có dữ liệu"
                  : `Hoàn thành / ${driver.finishedJobs ?? 0} đã kết thúc`
              }
            />
            <MetricCard
              icon="trend"
              tone="bg-success/10 text-success"
              label="Tỷ lệ hoàn thành"
              value={completionRateLabel(driver.completionRate)}
              hint={
                driver.completionRate == null
                  ? "Chưa có chuyến/đơn kết thúc"
                  : "Trên các chuyến/đơn đã nhận"
              }
            />
            <MetricCard
              icon="star"
              tone="bg-food/10 text-food"
              label="Đánh giá trung bình"
              value={
                driver.rating != null
                  ? `${String(driver.rating).replace(".", ",")}/5`
                  : "—"
              }
              hint={driver.rating != null ? "Từ khách hàng" : "Chưa có dữ liệu"}
            />
          </div>
          <div className="grid items-start gap-4 xl:grid-cols-3">
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="driver-profile"
                title={`Hồ sơ tài xế ${driver.code}`}
              >
                <div className="flex min-w-0 items-center gap-3">
                  <Avatar
                    letters={driver.initials}
                    tone="bg-brand/10 text-brand"
                    large
                  />
                  <div className="min-w-0">
                    <p className="font-semibold text-ink">{driver.name}</p>
                    <p className="text-sm text-muted">
                      {driver.service || "Đối tác vận hành"}
                    </p>
                    <div className="mt-2 flex flex-wrap gap-2">
                      <StatusChip tone={driverKycStatusTone(driver.kyc)}>
                        {driverKycStatusLabel(driver.kyc)}
                      </StatusChip>
                      <StatusChip tone="brand">
                        {driver.vehicleKind || "—"}
                      </StatusChip>
                    </div>
                  </div>
                </div>
                <div className="mt-4">
                  <FieldList
                    rows={[
                      { label: "Mã đối tác", value: driver.code },
                      {
                        label: "Điện thoại",
                        value: driver.phone || "Chưa có dữ liệu",
                      },
                      {
                        label: "Email",
                        value: driver.email || "Chưa có dữ liệu",
                      },
                      {
                        label: "Khu vực",
                        value: driver.area || "Chưa có dữ liệu",
                      },
                      {
                        label: "Ngày tham gia",
                        value: driver.createdAt
                          ? formatOpsDate(driver.createdAt)
                          : "Chưa có dữ liệu",
                      },
                      {
                        label: "Dịch vụ đủ điều kiện",
                        value: driver.service || "Chưa có dữ liệu",
                      },
                      {
                        label: "Trạng thái",
                        value:
                          driver.activity === "OFFLINE" ? (
                            <span className="inline-flex items-center rounded-full bg-canvas px-2.5 py-1 text-xs font-semibold text-muted">
                              {driverActivityStatusLabel(driver.activity)}
                            </span>
                          ) : (
                            <StatusChip
                              tone={driverActivityStatusTone(driver.activity)}
                            >
                              {driverActivityStatusLabel(driver.activity)}
                            </StatusChip>
                          ),
                      },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection
                id="driver-access"
                title="An toàn & quyền truy cập"
              >
                <p className="flex gap-2 rounded-xl bg-brand/5 px-3 py-3 text-sm text-muted">
                  <OpsIcon
                    name="lock"
                    className="mt-0.5 size-4 shrink-0 text-brand"
                  />
                  <span>
                    <span className="font-semibold text-ink">
                      Kiểm soát thao tác nhạy cảm.{" "}
                    </span>
                    Mọi hành động tạm khóa, sửa điều kiện hoạt động hoặc xem
                    giấy tờ gốc phải có quyền và lý do; lưu nhật ký kiểm toán.
                  </span>
                </p>
                <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <PreviewLink href="/exceptions" tone="neutral">
                    Xem sự cố
                  </PreviewLink>
                  <PreviewLink href="/drivers/kyc" tone="ghost">
                    Hàng đợi KYC
                  </PreviewLink>
                </div>
              </DetailSection>
              <AccountDeletionCard
                userId={driver.code}
                name={driver.name}
                deletion={driver.deletion}
              />
              <DriverFeeCard driverId={driver.code} name={driver.name} />
            </div>
            <div className="min-w-0 space-y-4">
              <DetailSection id="driver-live" title="Theo dõi vận hành">
                {driver.activeJob ? (
                  <div className="rounded-xl border border-brand/20 bg-brand/5 p-4 space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-2 text-sm font-semibold text-brand">
                        <span className="size-2 rounded-full bg-brand animate-ping" />
                        {driver.activeJob.type === 'RIDE' ? 'Chuyến xe đang thực hiện' : 'Đơn ăn đang giao'}
                      </span>
                      <StatusChip tone="brand">{driver.activeJob.statusLabel}</StatusChip>
                    </div>
                    <div className="text-sm">
                      <p className="font-semibold text-ink">{driver.activeJob.code} · {driver.activeJob.customerName}</p>
                      <p className="text-xs text-muted mt-1">{driver.activeJob.pickupLabel} → {driver.activeJob.dropoffLabel}</p>
                      <p className="text-sm font-bold text-ink mt-2">{vnd(driver.activeJob.fareVnd)}</p>
                    </div>
                  </div>
                ) : (
                  <div className="rounded-xl border border-border bg-canvas/30 p-4 space-y-2 text-sm">
                    <div className="flex items-center gap-2">
                      <span className={`size-2.5 rounded-full ${driver.presence?.online ? 'bg-success' : 'bg-muted'}`} />
                      <p className="font-semibold text-ink">
                        {driver.presence?.online ? 'Tài xế đang Trực tuyến (Online)' : 'Tài xế đang Ngoại tuyến (Offline)'}
                      </p>
                    </div>
                    <p className="text-xs text-muted">
                      Khu vực hoạt động: <span className="font-medium text-ink">{driver.area || "—"}</span>
                    </p>
                    {driver.presence?.lat && driver.presence?.lng ? (
                      <p className="text-xs text-muted">
                        Tọa độ GPS: <span className="font-mono text-ink">{driver.presence.lat.toFixed(4)}, {driver.presence.lng.toFixed(4)}</span>
                      </p>
                    ) : null}
                    <p className="text-xs text-muted">
                      Dịch vụ nhận chuyến: <span className="font-medium text-ink">{driver.service || "—"}</span>
                    </p>
                    {driver.presence?.updatedAt ? (
                      <p className="text-xs text-muted">
                        Cập nhật tín hiệu lần cuối: {formatOpsDate(driver.presence.updatedAt)}
                      </p>
                    ) : null}
                  </div>
                )}
              </DetailSection>

              <DetailSection
                id="driver-performance"
                title="Hiệu suất hoạt động"
                extra={
                  <span className="text-xs text-muted">7 ngày gần đây</span>
                }
              >
                {driver.performance7d && driver.performance7d.length > 0 ? (
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-xs">
                      <thead>
                        <tr className="border-b border-border text-muted">
                          <th className="py-2 pr-2 font-medium">Ngày</th>
                          <th className="py-2 px-2 text-center font-medium">Chuyến</th>
                          <th className="py-2 px-2 text-right font-medium">Tổng cước</th>
                          <th className="py-2 pl-2 text-right font-medium">Thu nhập</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-border/50">
                        {driver.performance7d.map((row) => (
                          <tr key={row.date} className="hover:bg-canvas/40">
                            <td className="py-2 pr-2 font-medium text-ink">{row.dayLabel}</td>
                            <td className="py-2 px-2 text-center text-ink">{row.completedTrips}</td>
                            <td className="py-2 px-2 text-right text-muted tabular-nums">{vnd(row.fareVnd)}</td>
                            <td className="py-2 pl-2 text-right font-semibold text-success tabular-nums">{vnd(row.netVnd)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <EmptyPanel message="Chưa có dữ liệu hiệu suất theo ngày." />
                )}
              </DetailSection>

              <DetailSection
                id="driver-activity"
                title="Hoạt động gần đây"
                extra={
                  <span className="text-xs text-muted">
                    {totalItems} mục
                  </span>
                }
              >
                <div className="min-w-0 overflow-x-auto">
                  <div
                    role="tablist"
                    aria-label="Phân loại hoạt động"
                    className="flex w-max min-w-full gap-3 border-b border-border pb-2"
                  >
                    {DRIVER_ACTIVITY_TABS.map((tab) => {
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
                              ? `border-b-2 border-brand px-1 pb-1 text-xs font-semibold whitespace-nowrap text-brand cursor-pointer ${focusRing}`
                              : `border-b-2 border-transparent px-1 pb-1 text-xs whitespace-nowrap text-muted hover:text-ink cursor-pointer ${focusRing}`
                          }
                        >
                          {tab}
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div className="mt-3">
                  {isActivitiesPending ? (
                    <div className="py-6 text-center text-xs text-muted animate-pulse">
                      Đang tải danh sách hoạt động…
                    </div>
                  ) : activities.length === 0 ? (
                    <EmptyPanel message="Chưa có hoạt động nào trong danh mục này." />
                  ) : (
                    <div className="space-y-3">
                      <div className="flex justify-end">
                        <ExportCsvButton
                          compact
                          filename={`${driver.code}-activities.csv`}
                          headers={["Thời gian", "Mã", "Loại", "Nội dung", "Giá trị", "Trạng thái"]}
                          rows={activities.map((a) => [a.time, a.code, a.kind, a.summary, a.value, a.status])}
                        >
                          <OpsIcon name="download" className="size-3.5" />
                          Xuất CSV
                        </ExportCsvButton>
                      </div>
                      <AdminTableContainer minWidth="min-w-[480px]">
                        <AdminTable caption="Hoạt động tài xế">
                          <AdminTableHeader>
                            <AdminTableRow>
                              <AdminTableHead>Thời gian</AdminTableHead>
                              <AdminTableHead>Mã</AdminTableHead>
                              <AdminTableHead>Lộ trình / Chi tiết</AdminTableHead>
                              <AdminTableHead className="text-right">Cước phí</AdminTableHead>
                              <AdminTableHead>Trạng thái</AdminTableHead>
                            </AdminTableRow>
                          </AdminTableHeader>
                          <AdminTableBody>
                            {activities.map((act) => (
                              <AdminTableRow key={act.code}>
                                <AdminTableCell className="text-xs text-muted whitespace-nowrap">
                                  {act.time}
                                </AdminTableCell>
                                <AdminTableCell className="font-mono text-xs font-semibold text-brand whitespace-nowrap">
                                  {act.code}
                                </AdminTableCell>
                                <AdminTableCell className="text-xs text-ink max-w-[200px] truncate" title={act.summary}>
                                  {act.summary}
                                </AdminTableCell>
                                <AdminTableCell className="text-right text-xs font-medium tabular-nums whitespace-nowrap">
                                  {act.value}
                                </AdminTableCell>
                                <AdminTableCell className="whitespace-nowrap">
                                  <StatusChip tone={act.tone as any}>
                                    {act.status}
                                  </StatusChip>
                                </AdminTableCell>
                              </AdminTableRow>
                            ))}
                          </AdminTableBody>
                        </AdminTable>
                      </AdminTableContainer>
                      {totalPages > 1 ? (
                        <div className="flex items-center justify-between text-xs text-muted pt-2">
                          <span>Trang {page} / {totalPages}</span>
                          <div className="flex gap-2">
                            <button
                              type="button"
                              disabled={page <= 1}
                              onClick={() => setPage((p) => Math.max(1, p - 1))}
                              className="rounded border border-border px-2 py-1 disabled:opacity-50 hover:bg-canvas/40"
                            >
                              Trước
                            </button>
                            <button
                              type="button"
                              disabled={page >= totalPages}
                              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                              className="rounded border border-border px-2 py-1 disabled:opacity-50 hover:bg-canvas/40"
                            >
                              Sau
                            </button>
                          </div>
                        </div>
                      ) : null}
                    </div>
                  )}
                </div>
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="driver-vehicle"
                title="Phương tiện đang sử dụng"
              >
                <div className="rounded-xl bg-brand/5 px-4 py-3">
                  <MotorbikeSketch />
                </div>
                <div className="mt-4 flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-semibold text-ink">
                      {driver.vehicle || "Chưa có dữ liệu"}
                    </p>
                    <p className="text-sm text-muted">
                      {driver.vehicleKind || "Loại phương tiện chưa có"}
                    </p>
                  </div>
                  <StatusChip tone="brand">
                    {driver.vehicleKind || "—"}
                  </StatusChip>
                </div>
                <div className="mt-2">
                  <FieldList
                    rows={[
                      {
                        label: "Biển kiểm soát",
                        value: driver.plate || "Chưa có dữ liệu",
                      },
                      {
                        label: "Loại dịch vụ",
                        value: driver.service || "Chưa có dữ liệu",
                      },
                      {
                        label: "Hạng GPLX",
                        value: driver.licenseClass ? `Hạng ${driver.licenseClass}` : "Chưa có dữ liệu",
                      },
                      {
                        label: "Số GPLX",
                        value: driver.licenseNumber || "Chưa có dữ liệu",
                      },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection id="driver-kyc" title="Trạng thái hồ sơ & KYC">
                {driver.kycDetail ? (
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium text-ink">Hồ sơ đối tác</span>
                      <StatusChip tone={driver.kycDetail.status === 'APPROVED' ? 'success' : driver.kycDetail.status === 'REJECTED' ? 'danger' : 'food'}>
                        {driver.kycDetail.status === 'APPROVED' ? 'Đã duyệt' : driver.kycDetail.status === 'REJECTED' ? 'Từ chối' : 'Chờ duyệt'}
                      </StatusChip>
                    </div>
                    <dl className="space-y-1.5 text-xs">
                      <div className="flex justify-between">
                        <dt className="text-muted">Mã hồ sơ KYC</dt>
                        <dd className="font-mono text-ink">{driver.kycDetail.applicationId.slice(0, 8)}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-muted">Hạng GPLX</dt>
                        <dd className="font-medium text-ink">{driver.kycDetail.licenseClass || "—"}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-muted">Số giấy tờ nộp</dt>
                        <dd className="font-medium text-ink">{driver.kycDetail.documentCount} tài liệu</dd>
                      </div>
                      {driver.kycDetail.submittedAt ? (
                        <div className="flex justify-between">
                          <dt className="text-muted">Thời gian nộp</dt>
                          <dd className="text-ink">{formatOpsDate(driver.kycDetail.submittedAt)}</dd>
                        </div>
                      ) : null}
                    </dl>
                    <div className="pt-2">
                      <PreviewLink href={`/drivers/kyc/${driver.kycDetail.applicationId}`} tone="brand">
                        Xem chi tiết hồ sơ KYC
                        <OpsIcon name="arrowRight" className="size-4" />
                      </PreviewLink>
                    </div>
                  </div>
                ) : (
                  <>
                    <EmptyPanel message="Chưa có danh sách giấy tờ KYC." />
                    <div className="mt-2">
                      <PreviewLink href="/drivers/kyc" tone="neutral">
                        Xem hàng đợi KYC
                      </PreviewLink>
                    </div>
                  </>
                )}
              </DetailSection>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function MetricCard({
  icon,
  tone,
  label,
  value,
  hint,
}: {
  icon: OpsIconName;
  tone: string;
  label: string;
  value: string;
  hint: string;
}) {
  return (
    <article className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-2">
        <p className="text-sm text-muted">{label}</p>
        <span
          className={`grid size-8 shrink-0 place-items-center rounded-lg ${tone}`}
        >
          <OpsIcon name={icon} className="size-4" />
        </span>
      </div>
      <p className="mt-2 text-2xl font-bold tracking-tight break-words text-ink tabular-nums">
        {value}
      </p>
      <p className="mt-1 text-xs text-muted">{hint}</p>
    </article>
  );
}

function MotorbikeSketch() {
  return (
    <svg
      viewBox="0 0 220 78"
      className="mx-auto h-16 w-full max-w-56"
      aria-hidden="true"
    >
      <circle
        cx="46"
        cy="54"
        r="16"
        fill="none"
        className="text-muted"
        stroke="currentColor"
        strokeWidth="3"
      />
      <circle
        cx="174"
        cy="54"
        r="16"
        fill="none"
        className="text-muted"
        stroke="currentColor"
        strokeWidth="3"
      />
      <path
        d="M62 54h22l18-24h36l16 10 20 14h2"
        fill="none"
        className="text-ink"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      <path
        d="M112 30h22"
        className="text-brand"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinecap="round"
      />
      <path
        d="M128 18v14"
        className="text-ink"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinecap="round"
      />
    </svg>
  );
}
