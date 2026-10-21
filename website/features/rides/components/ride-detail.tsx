"use client";

import { useMemo, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  PreviewButton,
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
  MoneyLines,
  RouteSketch,
  RouteStats,
  SampleNotFound,
  SummaryCell,
  SummaryStrip,
  TextAction,
} from "@/components/ui/admin-detail-ui";
import {
  OpsInterveneActionButton,
  OpsInterveneDialog,
} from "@/components/ui/ops-intervene-dialog";
import { LedgerJournalPanel } from "@/features/ledger/components/ledger-journal-panel";
import { useRideLedgerQuery } from "@/features/ledger/hooks";
import {
  useCancelRideMutation,
  useReassignRideMutation,
  useRideDetailQuery,
} from "@/features/rides/hooks";
import {
  canOpsCancelRide,
  canOpsReassignRide,
} from "@/features/rides/intervene";
import { rideStatusLabel, rideStatusTone } from "@/features/rides/mappers";
import { isForbiddenError } from "@/lib/api/errors";

type InterveneDialogState = null | "cancel" | "reassign";

export function RideDetail({ code }: { code: string }) {
  const {
    data: ride,
    isPending,
    isError,
    error,
    refetch,
  } = useRideDetailQuery(code);
  const forbidden = isError && isForbiddenError(error);
  const ledgerQuery = useRideLedgerQuery(code);
  const cancelMutation = useCancelRideMutation(code);
  const reassignMutation = useReassignRideMutation(code);
  const [dialog, setDialog] = useState<InterveneDialogState>(null);

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Chuyến xe", href: "/rides" },
      { label: ride?.code || code },
    ],
    [ride?.code, code],
  );

  const showCancel = ride ? canOpsCancelRide(ride.status) : false;
  const showReassign = ride
    ? canOpsReassignRide(ride.status, ride.driver)
    : false;
  const intervenePending =
    cancelMutation.isPending || reassignMutation.isPending;

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết chuyến xe"
            description="Tài khoản của bạn không được phân quyền xem hồ sơ chuyến xe này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết chuyến xe. Vui lòng thử lại."
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết chuyến xe…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !ride ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy chuyến xe"
          listHref="/rides"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết chuyến xe"
            actions={
              <>
                <BackToList href="/rides" />
                {showReassign ? (
                  <OpsInterveneActionButton
                    tone="brand"
                    pending={intervenePending}
                    onClick={() => setDialog("reassign")}
                  >
                    <OpsIcon name="refresh" className="size-4" />
                    Gỡ gán
                  </OpsInterveneActionButton>
                ) : null}
                {showCancel ? (
                  <OpsInterveneActionButton
                    tone="danger"
                    pending={intervenePending}
                    onClick={() => setDialog("cancel")}
                  >
                    <OpsIcon name="alert" className="size-4" />
                    Hủy chuyến
                  </OpsInterveneActionButton>
                ) : null}
              </>
            }
          />
          {dialog ? (
            <OpsInterveneDialog
              open
              kind={dialog}
              entityLabel={`Chuyến ${ride.code}`}
              pending={intervenePending}
              onClose={() => setDialog(null)}
              onConfirm={async (reason) => {
                if (dialog === "cancel") {
                  await cancelMutation.mutateAsync(reason);
                } else {
                  await reassignMutation.mutateAsync(reason);
                }
              }}
            />
          ) : null}
          <SummaryStrip columns={6}>
            <SummaryCell label="Mã chuyến">
              <span className="text-base text-brand">{ride.code}</span>
            </SummaryCell>
            <SummaryCell label="Hành trình" hint={ride.seats}>
              {ride.pickup} → {ride.dropoff}
            </SummaryCell>
            <SummaryCell label="Trạng thái" hint={ride.cancelledBy ?? undefined}>
              <StatusChip tone={rideStatusTone(ride.status)} dot>
                {rideStatusLabel(ride.status)}
              </StatusChip>
            </SummaryCell>
            <SummaryCell label="Giá đã chốt">
              <span className="text-lg tabular-nums">{vnd(ride.price)}</span>
            </SummaryCell>
            <SummaryCell label="Thanh toán">Tiền mặt</SummaryCell>
            <SummaryCell label="Dự kiến đến" hint="Cập nhật lúc 14:32">
              <span className="text-lg tabular-nums">14:47</span>
            </SummaryCell>
          </SummaryStrip>
          <div className="grid items-start gap-4 xl:grid-cols-2">
            <div className="min-w-0 space-y-4">
              <DetailSection id="ride-trip" title="Thông tin chuyến xe">
                <div className="flex min-w-0 items-center gap-3">
                  <Avatar
                    letters={initialsFromLabel(ride.customer)}
                    tone="bg-brand/10 text-brand"
                    large
                  />
                  <div className="min-w-0">
                    <p className="font-semibold text-ink">{ride.customer}</p>
                    <p className="text-sm text-muted">
                      Khách hàng ·{" "}
                      {ride.phone !== "—" ? ride.phone : "Chưa cập nhật SĐT"}
                    </p>
                  </div>
                </div>
                <div className="mt-4">
                  <FieldList
                    rows={[
                      { label: "Điểm đón", value: ride.pickup },
                      { label: "Điểm đến", value: ride.dropoff },
                      { label: "Hết hạn / ETA", value: ride.time },
                      { label: "Ghế / loại", value: ride.seats },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection id="ride-driver" title="Tài xế & phương tiện">
                <div className="flex min-w-0 items-start gap-3">
                  <Avatar
                    letters={initialsFromLabel(ride.driver)}
                    tone="bg-success/10 text-success"
                    large
                  />
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-semibold text-ink">{ride.driver}</p>
                      {ride.driver !== "—" ? (
                        <StatusChip tone="success">Đã gán</StatusChip>
                      ) : (
                        <StatusChip tone="food">Chưa gán</StatusChip>
                      )}
                    </div>
                    <p className="mt-1 text-sm text-muted">
                      Biển số: {ride.plate}
                    </p>
                  </div>
                </div>
                <div className="mt-4 flex min-w-0 flex-col gap-3 rounded-2xl bg-brand/5 p-3 sm:flex-row sm:items-center">
                  <div className="flex items-center gap-3">
                    <span className="grid size-12 shrink-0 place-items-center rounded-xl bg-brand/10 text-brand">
                      <OpsIcon name="motorcycle" className="size-6" />
                    </span>
                    <p className="font-semibold text-ink">
                      {ride.seats || "Xe máy hai bánh"}
                    </p>
                  </div>
                  <div className="min-w-0 text-sm sm:ml-auto">
                    <p className="font-medium text-ink">
                      {ride.driver !== "—"
                        ? `Tài xế: ${ride.driver}`
                        : "Chưa có tài xế nhận chuyến"}
                    </p>
                    <p className="text-ink">
                      Biển số:{" "}
                      {ride.plate !== "—" ? ride.plate : "Chưa cập nhật"}
                    </p>
                    <p className="text-muted">Hồ sơ đối tác DealGo Ride</p>
                  </div>
                </div>
              </DetailSection>
              <DetailSection
                id="ride-payment"
                title="Chi tiết thanh toán"
                extra={<StatusChip tone="brand">Tiền mặt</StatusChip>}
              >
                <MoneyLines
                  rows={[
                    { label: "Giá đã chốt / báo giá", amount: ride.price },
                    ...(ride.discountVnd > 0
                      ? [
                          {
                            label: `Voucher ${ride.voucherCode ?? ""} (DealGo tài trợ)`.trim(),
                            amount: -ride.discountVnd,
                          },
                        ]
                      : []),
                  ]}
                  totalLabel="Tiền mặt khách trả tài xế"
                  total={ride.cashDueVnd}
                />
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="ride-route"
                title="Lộ trình di chuyển"
                extra={
                  <TextAction>
                    Xem toàn màn hình
                    <OpsIcon name="arrowRight" className="size-4" />
                  </TextAction>
                }
              >
                <div className="relative min-w-0">
                  <RouteSketch
                    label={`Sơ đồ tuyến từ ${ride.pickup} đến ${ride.dropoff}`}
                    start={ride.pickupArea || ride.pickup}
                    end={ride.dropoffArea || ride.dropoff}
                    from={ride.pickupPoint}
                    to={ride.dropoffPoint}
                  />
                  <RouteStats
                    items={[
                      {
                        icon: "pin",
                        label: "Điểm đón",
                        value: ride.pickupArea || ride.pickup,
                      },
                      {
                        icon: "clock",
                        label: "Thời gian",
                        value: ride.time || "—",
                      },
                      {
                        icon: "pin",
                        label: "Điểm đến",
                        value: ride.dropoffArea || ride.dropoff,
                      },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection
                id="ride-timeline"
                title="Mốc thời gian & trạng thái"
                extra={
                  <StatusChip tone={rideStatusTone(ride.status)}>
                    {rideStatusLabel(ride.status)}
                  </StatusChip>
                }
              >
                <MilestoneList
                  items={[
                    {
                      time: ride.time || "—",
                      title: "Khởi tạo yêu cầu chuyến xe",
                      detail: `Mã chuyến ${ride.code} · ${ride.pickup}`,
                      tone: "done",
                    },
                    {
                      time: ride.driver !== "—" ? "Đã gán" : "Chờ ghép",
                      title:
                        ride.driver !== "—"
                          ? `Tài xế ${ride.driver} nhận chuyến`
                          : "Đang tìm tài xế",
                      detail:
                        ride.driver !== "—"
                          ? `Biển số: ${ride.plate}`
                          : "Hệ thống đang phát yêu cầu tới tài xế gần nhất",
                      tone:
                        ride.driver !== "—"
                          ? "done"
                          : ride.status === "WAITING"
                            ? "current"
                            : "upcoming",
                    },
                    {
                      time:
                        ride.status === "PICKING_UP" ||
                        ride.status === "IN_TRIP" ||
                        ride.status === "COMPLETED"
                          ? "Đang đón"
                          : "Chờ đón",
                      title: "Di chuyển đến điểm đón",
                      detail: ride.pickup,
                      tone:
                        ride.status === "IN_TRIP" || ride.status === "COMPLETED"
                          ? "done"
                          : ride.status === "PICKING_UP"
                            ? "current"
                            : "upcoming",
                    },
                    {
                      time:
                        ride.status === "IN_TRIP" || ride.status === "COMPLETED"
                          ? "Đang đi"
                          : "Chờ đi",
                      title: "Thực hiện hành trình",
                      detail: ride.dropoff,
                      tone:
                        ride.status === "COMPLETED"
                          ? "done"
                          : ride.status === "IN_TRIP"
                            ? "current"
                            : "upcoming",
                    },
                    {
                      time: ride.status === "COMPLETED" ? "Hoàn thành" : "—",
                      title:
                        ride.status === "COMPLETED"
                          ? "Chuyến xe hoàn thành"
                          : "Kết thúc hành trình",
                      detail: `Giá chốt: ${vnd(ride.price)}`,
                      tone: ride.status === "COMPLETED" ? "done" : "upcoming",
                    },
                  ]}
                />
              </DetailSection>
              <LedgerJournalPanel
                sectionId="ride-ledger"
                journal={ledgerQuery.data}
                isPending={ledgerQuery.isPending}
                isError={ledgerQuery.isError}
              />
              <DetailSection id="ride-support" title="Hỗ trợ & kiểm soát">
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <PreviewButton
                    onClick={() =>
                      document
                        .getElementById("ride-timeline")
                        ?.scrollIntoView({ behavior: "smooth", block: "start" })
                    }
                  >
                    <OpsIcon name="clock" className="size-4" />
                    Lịch sử
                  </PreviewButton>
                  <PreviewButton
                    onClick={() =>
                      document
                        .getElementById("ride-ledger")
                        ?.scrollIntoView({ behavior: "smooth", block: "start" })
                    }
                  >
                    <OpsIcon name="categories" className="size-4" />
                    Sổ cái
                  </PreviewButton>
                  <PreviewLink href="/exceptions" tone="ghost">
                    <OpsIcon name="headset" className="size-4" />
                    Hàng đợi ngoại lệ
                  </PreviewLink>
                  <PreviewLink href="/exceptions" tone="danger">
                    <OpsIcon name="alert" className="size-4" />
                    Báo cáo sự cố
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

function initialsFromLabel(label: string): string {
  const cleaned = label.replace(/[^0-9A-Za-zÀ-ỹ]/g, " ").trim();
  const parts = cleaned.split(/\s+/).filter(Boolean);
  if (parts.length === 0) {
    return "—";
  }
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase();
  }
  return `${parts[0][0] ?? ""}${parts[parts.length - 1][0] ?? ""}`.toUpperCase();
}
