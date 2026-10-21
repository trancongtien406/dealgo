"use client";

import { useMemo } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  PreviewLink,
  StatusChip,
  vnd,
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
  MilestoneList,
  RouteSketch,
  SampleNotFound,
} from "@/components/ui/admin-detail-ui";
import { useDeliveryDetailQuery } from "@/features/deliveries/hooks";
import {
  deliveryStatusLabel,
  deliveryStatusTone,
} from "@/features/deliveries/mappers";
import { isForbiddenError } from "@/lib/api/errors";

export function DeliveryDetail({ code }: { code: string }) {
  const {
    data: delivery,
    isPending,
    isError,
    error,
    refetch,
  } = useDeliveryDetailQuery(code);
  const forbidden = isError && isForbiddenError(error);

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Giao hàng", href: "/deliveries" },
      { label: delivery?.code || code },
    ],
    [delivery?.code, code],
  );

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết đơn giao hàng"
            description="Tài khoản của bạn không được cấp quyền xem hồ sơ đơn giao hàng này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết đơn giao hàng. Vui lòng thử lại."
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết đơn giao hàng…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !delivery ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy đơn giao hàng"
          listHref="/deliveries"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết đơn giao hàng"
            subtitle="Theo dõi vận đơn, tài xế, tuyến đường và quá trình giao nhận."
            actions={
              <>
                <BackToList href="/deliveries" />
              </>
            }
          />
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs text-muted">Mã vận đơn</p>
              <p className="mt-1 text-base font-semibold break-words text-brand">
                {delivery.code}
              </p>
            </li>
            <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs text-muted">Trạng thái</p>
              <div className="mt-1">
                <StatusChip tone={deliveryStatusTone(delivery.status)} dot>
                  {deliveryStatusLabel(delivery.status)}
                </StatusChip>
              </div>
            </li>
            <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs text-muted">Phí giao đã chốt</p>
              <p className="mt-1 text-lg font-semibold text-ink tabular-nums">
                {vnd(delivery.fee)}
              </p>
            </li>
            <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs text-muted">Loại hàng</p>
              <p className="mt-1 text-sm font-semibold text-ink">
                {delivery.cargo}
              </p>
            </li>
            <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs text-muted">Thời gian</p>
              <p className="mt-1 text-sm font-semibold text-ink">
                {delivery.time || "—"}
              </p>
            </li>
          </ul>
          <div className="grid items-start gap-4 xl:grid-cols-2">
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="delivery-parties"
                title="Thông tin gửi và nhận"
                extra={
                  <span className="text-xs text-muted">Vận đơn độc lập</span>
                }
              >
                <Party
                  letters={(delivery.sender || "G").slice(0, 2).toUpperCase()}
                  tone="bg-brand/10 text-brand"
                  name={delivery.sender}
                  role="Người gửi đơn"
                />
                <div className="mt-3">
                  <FieldList
                    rows={[
                      { label: "Tuyến / Điểm giao", value: delivery.route },
                    ]}
                  />
                </div>
              </DetailSection>
              <div className="grid items-start gap-4 lg:grid-cols-2">
                <DetailSection id="delivery-cargo" title="Hàng hóa & yêu cầu">
                  <FieldList
                    rows={[
                      { label: "Mô tả / Loại hàng", value: delivery.cargo },
                      {
                        label: "Khu vực",
                        value: delivery.regionLabel || "Đang cập nhật",
                      },
                      {
                        label: "Trạng thái",
                        value: deliveryStatusLabel(delivery.status),
                      },
                    ]}
                  />
                </DetailSection>
                <DetailSection id="delivery-driver" title="Tài xế phụ trách">
                  {delivery.driver ? (
                    <>
                      <div className="flex min-w-0 items-center gap-3">
                        <Avatar
                          letters={delivery.driver.slice(0, 2).toUpperCase()}
                          tone="bg-success/10 text-success"
                          large
                        />
                        <div className="min-w-0">
                          <p className="font-semibold text-ink">
                            {delivery.driver}
                          </p>
                          <p className="text-sm text-muted">
                            Tài xế đã nhận đơn
                          </p>
                        </div>
                      </div>
                      <div className="mt-3">
                        <FieldList
                          rows={[
                            {
                              label: "Trạng thái",
                              value: (
                                <StatusChip
                                  tone={deliveryStatusTone(delivery.status)}
                                >
                                  {deliveryStatusLabel(delivery.status)}
                                </StatusChip>
                              ),
                            },
                          ]}
                        />
                      </div>
                    </>
                  ) : (
                    <p className="text-sm text-muted">Chưa phân công tài xế</p>
                  )}
                </DetailSection>
              </div>
              <DetailSection
                id="delivery-payment"
                title="Thanh toán & đối soát"
                extra={
                  <span className="text-xs text-muted">
                    Giá tại thời điểm chốt
                  </span>
                }
              >
                <ul className="divide-y divide-border">
                  <li className="flex items-baseline justify-between gap-4 py-2.5 text-sm">
                    <span className="min-w-0 text-muted">
                      Phí giao hàng (khách thanh toán)
                    </span>
                    <span className="shrink-0 font-medium text-ink tabular-nums">
                      {vnd(delivery.fee)}
                    </span>
                  </li>
                </ul>
                <div className="mt-3 flex flex-wrap items-center justify-between gap-2 rounded-xl bg-brand/10 px-4 py-3 text-sm font-semibold text-brand">
                  <span>Tổng phải thu</span>
                  <span className="text-base tabular-nums">
                    {vnd(delivery.fee)}
                  </span>
                </div>
                <p className="mt-3 text-sm text-muted">
                  Khoản thu hộ chỉ được cập nhật sau khi có xác nhận giao và
                  thanh toán nộp về.
                </p>
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="delivery-map"
                title="Bản đồ hành trình"
                extra={
                  <StatusChip tone={deliveryStatusTone(delivery.status)}>
                    {deliveryStatusLabel(delivery.status)}
                  </StatusChip>
                }
              >
                <div className="relative min-w-0">
                  <RouteSketch
                    label={`Sơ đồ tuyến giao ${delivery.code}`}
                    start={delivery.sender}
                    end={delivery.route}
                    from={delivery.pickupPoint}
                    to={delivery.dropoffPoint}
                  />
                </div>
                <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted">
                  <li>Điểm gửi: {delivery.sender}</li>
                  <li>Điểm giao: {delivery.route}</li>
                </ul>
              </DetailSection>
              <DetailSection
                id="delivery-timeline"
                title="Mốc thời gian xử lý"
                extra={
                  <span className="text-xs text-muted">
                    {delivery.time || "Theo thời gian thực"}
                  </span>
                }
              >
                <MilestoneList
                  items={[
                    {
                      time: delivery.time || "—",
                      title: "Khởi tạo đơn vận chuyển",
                      detail: `Mã vận đơn ${delivery.code} · ${delivery.cargo}`,
                      tone: "done",
                    },
                    {
                      time: delivery.driver ? "Đã gán" : "Chờ gán",
                      title: delivery.driver
                        ? `Tài xế ${delivery.driver} tiếp nhận`
                        : "Đang điều phối tài xế",
                      detail: delivery.driver
                        ? "Đã xác nhận thực hiện đơn"
                        : "Hệ thống đang tìm tài xế gần nhất",
                      tone: delivery.driver
                        ? "done"
                        : delivery.status === "WAITING_DRIVER"
                          ? "current"
                          : "upcoming",
                    },
                    {
                      time:
                        delivery.status === "PICKED_UP" ||
                        delivery.status === "DELIVERING" ||
                        delivery.status === "COMPLETED"
                          ? "Đã lấy"
                          : "Chờ lấy",
                      title: "Lấy hàng từ người gửi",
                      detail: delivery.sender,
                      tone:
                        delivery.status === "PICKED_UP" ||
                        delivery.status === "DELIVERING" ||
                        delivery.status === "COMPLETED"
                          ? "done"
                          : delivery.status === "WAITING_DRIVER"
                            ? "upcoming"
                            : "current",
                    },
                    {
                      time:
                        delivery.status === "COMPLETED"
                          ? "Hoàn thành"
                          : "Đang giao",
                      title:
                        delivery.status === "COMPLETED"
                          ? "Đã giao thành công"
                          : "Vận chuyển đến điểm giao",
                      detail: delivery.route,
                      tone:
                        delivery.status === "COMPLETED"
                          ? "done"
                          : delivery.status === "DELIVERING"
                            ? "current"
                            : "upcoming",
                    },
                  ]}
                />
              </DetailSection>
              <DetailSection id="delivery-support" title="Hỗ trợ & kiểm soát">
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <PreviewLink href="/exceptions" tone="ghost">
                    <OpsIcon name="headset" className="size-4" />
                    Hàng đợi ngoại lệ
                  </PreviewLink>
                  <PreviewLink href="/exceptions" tone="neutral">
                    <OpsIcon name="alert" className="size-4" />
                    Báo cáo sự cố
                  </PreviewLink>
                </div>
                <p className="mt-3 text-sm text-muted">
                  Admin không được tự xác nhận giao hàng hoặc thanh toán thay
                  cho các bên khi thiếu chứng cứ.
                </p>
              </DetailSection>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function Party({
  letters,
  tone,
  name,
  role,
}: {
  letters: string;
  tone: string;
  name: string;
  role: string;
}) {
  return (
    <div className="mt-4 flex min-w-0 items-center gap-3 first:mt-0">
      <Avatar letters={letters} tone={tone} />
      <div className="min-w-0">
        <p className="font-semibold text-ink">{name}</p>
        <p className="text-sm break-words text-muted">{role}</p>
      </div>
    </div>
  );
}
