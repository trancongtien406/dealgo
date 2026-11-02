"use client";

import { useMemo, useState } from "react";
import { ChatReviewButton } from "@/features/chat-review/components/chat-review-button";
import {
  useCancelFoodOrderMutation,
  useFoodOrderDetailQuery,
  useReassignFoodOrderMutation,
} from "@/features/food-orders/hooks";
import {
  canOpsCancelFoodOrder,
  canOpsReassignFoodOrder,
} from "@/features/food-orders/intervene";
import {
  foodOrderStatusLabel,
  foodOrderStatusTone,
} from "@/features/food-orders/mappers";
import { LedgerJournalPanel } from "@/features/ledger/components/ledger-journal-panel";
import { useFoodOrderLedgerQuery } from "@/features/ledger/hooks";
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
  SampleNotFound,
  SummaryCell,
  SummaryStrip,
  TextAction,
} from "@/components/ui/admin-detail-ui";
import {
  OpsInterveneActionButton,
  OpsInterveneDialog,
} from "@/components/ui/ops-intervene-dialog";
import { isForbiddenError } from "@/lib/api/errors";

type InterveneDialogState = null | "cancel" | "reassign";

export function FoodOrderDetail({ code }: { code: string }) {
  const {
    data: order,
    isPending,
    isError,
    error,
    refetch,
  } = useFoodOrderDetailQuery(code);
  const forbidden = isError && isForbiddenError(error);
  const ledgerQuery = useFoodOrderLedgerQuery(code);
  const cancelMutation = useCancelFoodOrderMutation(code);
  const reassignMutation = useReassignFoodOrderMutation(code);
  const [dialog, setDialog] = useState<InterveneDialogState>(null);

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Đơn đồ ăn", href: "/food-orders" },
      { label: order?.code || code },
    ],
    [order?.code, code],
  );

  const showCancel = order ? canOpsCancelFoodOrder(order.status) : false;
  const showReassign = order
    ? canOpsReassignFoodOrder(order.status, order.driver)
    : false;
  const intervenePending =
    cancelMutation.isPending || reassignMutation.isPending;

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết đơn đồ ăn"
            description="Tài khoản của bạn không được phân quyền xem hồ sơ đơn đồ ăn này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết đơn đồ ăn. Vui lòng thử lại."
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết đơn đồ ăn…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !order ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy đơn đồ ăn"
          listHref="/food-orders"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết đơn đồ ăn"
            subtitle="Theo dõi thực hiện đơn, thanh toán và bàn giao cho tài xế."
            actions={
              <>
                <BackToList href="/food-orders" />
                <ChatReviewButton
                  kind="food"
                  id={code}
                  partnerLabel="Tài xế/Cửa hàng"
                />

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
                    Hủy đơn
                  </OpsInterveneActionButton>
                ) : null}
              </>
            }
          />
          {dialog ? (
            <OpsInterveneDialog
              open
              kind={dialog}
              entityLabel={`Đơn ${order.code}`}
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
          <SummaryStrip columns={5}>
            <SummaryCell label="Mã đơn hàng" hint={order.time}>
              <span className="text-base text-brand">{order.code}</span>
            </SummaryCell>
            <SummaryCell
              label="Trạng thái"
              hint={order.cancelledBy ?? order.store}
            >
              <StatusChip tone={foodOrderStatusTone(order.status)} dot>
                {foodOrderStatusLabel(order.status)}
              </StatusChip>
            </SummaryCell>
            <SummaryCell label="Tổng khách trả" hint="Đã chốt giá">
              <span className="text-lg tabular-nums">{vnd(order.total)}</span>
            </SummaryCell>
            <SummaryCell label="Thanh toán" hint="COD · thu khi giao">
              <StatusChip tone="brand">{order.payment}</StatusChip>
            </SummaryCell>
            {order.cancelReason ? (
              <SummaryCell label="Lý do huỷ" hint="Khách thấy lý do này">
                <span className="text-sm font-semibold text-danger">
                  {order.cancelReason}
                </span>
              </SummaryCell>
            ) : (
              <SummaryCell
                label="Tài xế"
                hint={order.driver ? "Đã gán tài xế" : "Chưa gán tài xế"}
              >
                <span className="text-sm font-semibold">
                  {order.driver ?? "—"}
                </span>
              </SummaryCell>
            )}
          </SummaryStrip>
          <div className="grid items-start gap-4 xl:grid-cols-2">
            <div className="min-w-0 space-y-4">
              <DetailSection id="food-customer" title="Thông tin khách hàng">
                <div className="flex min-w-0 items-center gap-3">
                  <Avatar
                    letters={initialsFromLabel(order.customer)}
                    tone="bg-brand/10 text-brand"
                    large
                  />
                  <div className="min-w-0">
                    <p className="font-semibold text-ink">{order.customer}</p>
                    <p className="text-sm text-muted">
                      {order.customerPhone ?? "Khách hàng"}
                    </p>
                  </div>
                </div>
                <div className="mt-4">
                  <FieldList
                    rows={[
                      { label: "Cửa hàng", value: order.store },
                      { label: "Món (tóm tắt)", value: order.items },
                      { label: "Loại đơn", value: "Đồ ăn · Giao tận nơi" },
                      { label: "Phương thức", value: order.payment },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection
                id="food-items"
                title="Chi tiết món đã đặt"
                extra={
                  order.lines.length > 0 ? (
                    <span className="text-sm font-medium text-brand">
                      {order.lines.length} món
                    </span>
                  ) : null
                }
              >
                {order.lines.length === 0 ? (
                  <p className="py-4 text-sm text-muted">
                    Chưa có món trong đơn
                  </p>
                ) : (
                  <ul className="divide-y divide-border">
                    {order.lines.map((line, index) => (
                      <li
                        key={`${line.name}-${index}`}
                        className="flex min-w-0 items-center gap-3 py-3"
                      >
                        <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-food/10 text-food">
                          <OpsIcon name="utensils" className="size-5" />
                        </span>
                        <div className="min-w-0 flex-1">
                          <p className="font-medium text-ink">{line.name}</p>
                          {line.options ? (
                            <p
                              className="text-sm text-ink/80"
                              data-testid="food-line-options"
                            >
                              {line.options}
                            </p>
                          ) : null}
                          <p className="text-sm text-muted">
                            SL {line.quantity} · {vnd(line.unitPriceVnd)}/món
                          </p>
                        </div>
                        <p className="shrink-0 font-semibold tabular-nums text-ink">
                          {vnd(line.unitPriceVnd * line.quantity)}
                        </p>
                      </li>
                    ))}
                  </ul>
                )}
              </DetailSection>
              {order.change ? (
                <DetailSection
                  id="food-change"
                  title="Quán sửa đơn"
                  extra={
                    <StatusChip tone={order.change.statusTone}>
                      {order.change.status}
                    </StatusChip>
                  }
                >
                  <FieldList
                    rows={[
                      { label: "Lý do", value: order.change.reason },
                      {
                        label: "Món thay đổi",
                        value: order.change.lines.join("; "),
                      },
                      {
                        label: "Tạm tính",
                        value: `${vnd(order.change.oldSubtotalVnd)} → ${vnd(order.change.newSubtotalVnd)}`,
                      },
                      {
                        label: "Tổng mới",
                        value: vnd(order.change.newTotalVnd),
                      },
                      {
                        label: "Gửi lúc",
                        value: `${order.change.createdAt} · hạn ${order.change.answerBy}`,
                      },
                      {
                        label: "Khách trả lời",
                        value: order.change.respondedAt ?? "—",
                      },
                    ]}
                  />
                </DetailSection>
              ) : null}
              <DetailSection
                id="food-delivery-fee"
                title="Phí giao (thoả thuận)"
                extra={
                  <StatusChip tone={order.fee.agreed ? "success" : "brand"}>
                    {order.fee.agreed ? "Đã chốt" : "Đang thương lượng"}
                  </StatusChip>
                }
              >
                <FieldList
                  rows={[
                    {
                      label: "Phí gợi ý",
                      value: order.fee.suggested == null ? "—" : vnd(order.fee.suggested),
                    },
                    {
                      label: order.fee.agreed ? "Phí đã thoả thuận" : "Khách đang đề nghị",
                      value: vnd(order.fee.current),
                    },
                    { label: "Số lần khách tăng giá", value: String(order.fee.raiseCount) },
                    { label: "Chế độ phí giao", value: order.fee.mode ?? "—" },
                  ]}
                />
                {order.fee.offers.length > 0 ? (
                  <ul className="mt-3 space-y-1 text-sm">
                    {order.fee.offers.map((offer) => (
                      <li key={offer.id} className="flex justify-between gap-3">
                        <span>{offer.driver} · {offer.status}</span>
                        <span className="tabular-nums">{vnd(offer.amount)}</span>
                      </li>
                    ))}
                  </ul>
                ) : null}
              </DetailSection>
              <DetailSection
                id="food-payment"
                title="Chi tiết thanh toán & đối soát"
                extra={<StatusChip tone="brand">{order.payment}</StatusChip>}
              >
                <MoneyLines
                  rows={[{ label: "Tổng đơn", amount: order.total }]}
                  totalLabel="Khách thanh toán · COD"
                  total={order.total}
                />
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="food-progress"
                title="Tiến trình thực hiện"
                extra={
                  <StatusChip tone={foodOrderStatusTone(order.status)}>
                    {foodOrderStatusLabel(order.status)}
                  </StatusChip>
                }
              >
                <MilestoneList
                  items={[
                    {
                      time: order.time || "—",
                      title: "Khách đã đặt đơn",
                      detail: `Tạo đơn ${order.code} · ${order.customer}`,
                      tone: "done",
                    },
                    {
                      time:
                        order.status !== "AWAITING_CONFIRMATION"
                          ? "Đã tiếp nhận"
                          : "Chờ quán",
                      title: "Nhà hàng tiếp nhận đơn",
                      detail: order.store,
                      tone:
                        order.status !== "AWAITING_CONFIRMATION"
                          ? "done"
                          : "current",
                    },
                    {
                      time:
                        order.status === "DELIVERING" ||
                        order.status === "COMPLETED"
                          ? "Đang giao"
                          : "Chuẩn bị",
                      title:
                        order.status === "DELIVERING" ||
                        order.status === "COMPLETED"
                          ? "Bàn giao tài xế giao hàng"
                          : "Đang chuẩn bị món",
                      detail: order.driver
                        ? `Tài xế ${order.driver}`
                        : "Chờ điều phối tài xế",
                      tone:
                        order.status === "COMPLETED"
                          ? "done"
                          : order.status === "DELIVERING"
                            ? "current"
                            : "upcoming",
                    },
                    {
                      time: order.status === "COMPLETED" ? "Hoàn tất" : "—",
                      title:
                        order.status === "COMPLETED"
                          ? "Giao hàng thành công"
                          : "Chờ giao tới khách hàng",
                      detail: `Tổng thu: ${vnd(order.total)}`,
                      tone: order.status === "COMPLETED" ? "done" : "upcoming",
                    },
                  ]}
                />
              </DetailSection>
              <DetailSection
                id="food-route"
                title="Nhà hàng, tài xế & tuyến giao"
                extra={
                  <TextAction>
                    Xem vận hành
                    <OpsIcon name="arrowRight" className="size-4" />
                  </TextAction>
                }
              >
                <div className="grid gap-3 sm:grid-cols-2">
                  <article className="min-w-0 rounded-xl border border-border p-3">
                    <p className="text-xs font-medium tracking-wide text-muted uppercase">
                      Nhà hàng
                    </p>
                    <p className="mt-1 font-semibold text-ink">{order.store}</p>
                    <p className="text-sm text-muted">Từ đơn hàng</p>
                    <div className="mt-2">
                      <StatusChip tone="success">Cửa hàng</StatusChip>
                    </div>
                  </article>
                  <article className="min-w-0 rounded-xl border border-border p-3">
                    <p className="text-xs font-medium tracking-wide text-muted uppercase">
                      Tài xế giao hàng
                    </p>
                    <p className="mt-1 font-semibold text-ink">
                      {order.driver ?? "Chưa gán"}
                    </p>
                    <p className="text-sm text-muted">
                      {order.driver ? "Đã điều phối" : "Chưa có tài xế"}
                    </p>
                    <div className="mt-2">
                      <StatusChip tone={order.driver ? "brand" : "food"}>
                        {order.driver ? "Đã gán" : "Chưa gán"}
                      </StatusChip>
                    </div>
                  </article>
                </div>
                <div className="relative mt-3 min-w-0">
                  <RouteSketch
                    label={`Sơ đồ tuyến từ ${order.store} đến ${order.regionLabel || "Điểm giao"}`}
                    start={order.store}
                    end={order.regionLabel || "Điểm giao"}
                    from={order.pickupPoint}
                    to={order.dropoffPoint}
                  />
                </div>
              </DetailSection>
              <LedgerJournalPanel
                sectionId="food-ledger"
                journal={ledgerQuery.data}
                isPending={ledgerQuery.isPending}
                isError={ledgerQuery.isError}
              />
              <DetailSection id="food-support" title="Hỗ trợ & kiểm soát">
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <PreviewButton
                    onClick={() =>
                      document
                        .getElementById("food-progress")
                        ?.scrollIntoView({ behavior: "smooth", block: "start" })
                    }
                  >
                    <OpsIcon name="clock" className="size-4" />
                    Nhật ký đơn
                  </PreviewButton>
                  <PreviewButton
                    onClick={() =>
                      document
                        .getElementById("food-ledger")
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
