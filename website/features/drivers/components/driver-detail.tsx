"use client";

import { useMemo } from "react";
import { useDriverDetailQuery } from "@/features/drivers/hooks";
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
  PreviewLink,
  StatusChip,
} from "@/components/ui/admin-list-ui";
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
                      { label: "Điện thoại", value: "Chưa có dữ liệu" },
                      { label: "Email", value: "Chưa có dữ liệu" },
                      {
                        label: "Khu vực",
                        value: driver.area || "Chưa có dữ liệu",
                      },
                      { label: "Ngày tham gia", value: "Chưa có dữ liệu" },
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
              <DetailSection
                id="driver-performance"
                title="Hiệu suất hoạt động"
                extra={
                  <span className="text-xs text-muted">7 ngày gần đây</span>
                }
              >
                <EmptyPanel message="Chưa có dữ liệu hiệu suất theo ngày." />
              </DetailSection>
              <DetailSection
                id="driver-activity"
                title="Hoạt động gần đây"
                extra={
                  <span className="text-xs text-muted">
                    Theo dòng thời gian
                  </span>
                }
              >
                <EmptyPanel message="Chưa có dữ liệu hoạt động gần đây." />
              </DetailSection>
              <DetailSection id="driver-live" title="Theo dõi vận hành">
                <EmptyPanel message="Chưa có chuyến đang chạy trên hồ sơ này." />
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
                        label: "Đăng ký xe",
                        value: "Chưa có dữ liệu",
                      },
                      {
                        label: "Điều kiện lái xe",
                        value: "Chưa có dữ liệu",
                      },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection id="driver-kyc" title="Trạng thái hồ sơ & KYC">
                <EmptyPanel message="Chưa có danh sách giấy tờ KYC." />
                <div className="mt-2">
                  <PreviewLink href="/drivers/kyc" tone="neutral">
                    Xem hàng đợi KYC
                  </PreviewLink>
                </div>
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
