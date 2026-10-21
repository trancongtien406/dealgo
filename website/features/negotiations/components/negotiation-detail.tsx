"use client";

import { useMemo } from "react";
import { useNegotiationDetailQuery } from "@/features/negotiations/hooks";
import {
  negotiationOfferKindLabel,
  negotiationOfferStatusLabel,
  negotiationOfferStatusTone,
  negotiationSessionStatusLabel,
} from "@/features/negotiations/mappers";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
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
  RouteSketch,
  SampleNotFound,
  TextAction,
} from "@/components/ui/admin-detail-ui";
import {
  AdminTableContainer,
  AdminTable,
  AdminTableHeader,
  AdminTableHead,
  AdminTableBody,
  AdminTableRow,
  AdminTableCell,
} from "@/components/ui/admin-table";
import { NEGOTIATION_OFFER_TABLE_COLUMNS } from "@/features/negotiations/constants";
import { isForbiddenError } from "@/lib/api/errors";

export function NegotiationDetail({ code }: { code: string }) {
  const {
    data: session,
    isPending,
    isError,
    error,
    refetch,
  } = useNegotiationDetailQuery(code);
  const forbidden = isError && isForbiddenError(error);

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Phiên trả giá", href: "/negotiations" },
      { label: session?.code || code },
    ],
    [session?.code, code],
  );

  const [pickupLabel, dropoffLabel] = session
    ? splitRoute(session.route)
    : ["Điểm đón", "Điểm đến"];

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết phiên trả giá"
            description="Tài khoản của bạn không được phân quyền xem hồ sơ phiên này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message={
              error instanceof Error
                ? error.message
                : "Không tải được phiên trả giá."
            }
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết phiên trả giá…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !session ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy phiên trả giá"
          listHref="/negotiations"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết phiên trả giá"
            actions={
              <>
                <BackToList href="/negotiations" />
              </>
            }
          />
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            <Summary
              icon="gavel"
              tone="bg-brand/10 text-brand"
              label="Mã phiên trả giá"
              value={session.code.slice(0, 8)}
              hint={`${negotiationSessionStatusLabel(session.status)} · ${session.customer}`}
            />
            <Summary
              icon="wallet"
              tone="bg-brand/10 text-brand"
              label="Ngân sách khách hàng"
              value={vnd(session.budget)}
            />
            <Summary
              icon="trend"
              tone="bg-success/10 text-success"
              label="Đề xuất tốt nhất"
              value={session.lowest == null ? "—" : vnd(session.lowest)}
            />
            <Summary
              icon="clock"
              tone="bg-delivery/10 text-delivery"
              label="Số đề xuất"
              value={String(session.bids)}
            />
            <Summary
              icon="clock"
              tone="bg-food/10 text-food"
              label="Hạn hẹn phiên"
              value={session.expires}
              hint={session.expiresDate}
            />
          </ul>
          <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,20rem)]">
            <div className="min-w-0 space-y-4">
              <DetailSection id="negotiation-request" title="Thông tin yêu cầu">
                <div className="grid gap-x-6 lg:grid-cols-2">
                  <FieldList
                    rows={[
                      {
                        label: "Khách hàng",
                        value: session.customer,
                      },
                      { label: "Số điện thoại", value: session.customerPhone ?? "—" },
                      {
                        label: "Trạng thái",
                        value: negotiationSessionStatusLabel(session.status),
                      },
                      {
                        label: "Hạn phiên",
                        value:
                          session.expires === "—"
                            ? "—"
                            : `${session.expires} · ${session.expiresDate}`,
                      },
                    ]}
                  />
                  <FieldList
                    rows={[
                      {
                        label: "Điểm đón",
                        value: <Place name={pickupLabel} tone="bg-success" />,
                      },
                      {
                        label: "Điểm đến",
                        value: <Place name={dropoffLabel} tone="bg-danger" />,
                      },
                      {
                        label: "Tuyến",
                        value: session.route,
                      },
                    ]}
                  />
                </div>
              </DetailSection>
              <DetailSection
                id="negotiation-bids"
                title={`Danh sách đề xuất (${session.bids})`}
              >
                {session.offers.length === 0 ? (
                  <p className="text-sm text-muted">Chưa có đề xuất</p>
                ) : (
                  <AdminTableContainer>
                    <AdminTable minWidth="min-w-[32rem]">
                      <AdminTableHeader>
                        <AdminTableRow>
                          {NEGOTIATION_OFFER_TABLE_COLUMNS.map((col) => (
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
                        {session.offers.map((offer) => (
                          <AdminTableRow key={offer.id}>
                            <AdminTableCell className="font-medium">
                              <span className="block">{offer.driverLabel}</span>
                              {offer.driverPlate ? (
                                <span className="block text-xs text-muted">
                                  {offer.driverPlate}
                                </span>
                              ) : null}
                            </AdminTableCell>
                            <AdminTableCell
                              align="right"
                              className="font-semibold tabular-nums"
                            >
                              {vnd(offer.amountVnd)}
                            </AdminTableCell>
                            <AdminTableCell>
                              {negotiationOfferKindLabel(offer.kind)}
                            </AdminTableCell>
                            <AdminTableCell>
                              <StatusChip
                                tone={negotiationOfferStatusTone(offer.status)}
                              >
                                {negotiationOfferStatusLabel(offer.status)}
                              </StatusChip>
                            </AdminTableCell>
                          </AdminTableRow>
                        ))}
                      </AdminTableBody>
                    </AdminTable>
                  </AdminTableContainer>
                )}
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <DetailSection
                id="negotiation-map"
                title="Bản đồ hành trình"
                extra={
                  <TextAction>
                    Xem lộ trình
                    <OpsIcon name="arrowRight" className="size-4" />
                  </TextAction>
                }
              >
                <RouteSketch
                  label={`Sơ đồ tuyến từ ${pickupLabel} đến ${dropoffLabel}`}
                  start={pickupLabel}
                  end={dropoffLabel}
                  from={session.pickupPoint}
                  to={session.dropoffPoint}
                />
              </DetailSection>
              <DetailSection
                id="negotiation-stats"
                title="Thống kê phiên trả giá"
              >
                <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <Stat
                    icon="car"
                    label="Số đề xuất"
                    value={String(session.bids)}
                  />
                  <Stat
                    icon="trend"
                    label="Giá tốt nhất / chốt"
                    value={session.lowest == null ? "—" : vnd(session.lowest)}
                  />
                  <Stat
                    icon="wallet"
                    label="Ngân sách khách"
                    value={vnd(session.budget)}
                  />
                  <Stat
                    icon="clock"
                    label="Hạn phiên"
                    value={session.expires}
                    hint={negotiationSessionStatusLabel(session.status)}
                  />
                </ul>
              </DetailSection>
              <DetailSection
                id="negotiation-actions"
                title="Thao tác phiên trả giá"
              >
                <p className="text-sm text-muted">
                  Hệ thống tự động điều phối phiên trả giá giữa khách hàng và
                  tài xế theo thời gian thực. Trường hợp phát sinh tranh chấp
                  hoặc lỗi kẹt phiên, vui lòng xử lý tại hàng đợi ngoại lệ.
                </p>
              </DetailSection>
              <DetailSection id="negotiation-log" title="Nhật ký hoạt động">
                <p className="text-sm text-muted">
                  Chưa có nhật ký hoạt động. Tuyến: {session.route}.
                </p>
              </DetailSection>
            </div>
          </div>
        </>
      )}
    </div>
  );
}



function splitRoute(route: string): [string, string] {
  const parts = route.split("→").map((part) => part.trim());
  return [parts[0] || "Điểm đón", parts[1] || "Điểm đến"];
}

function Summary({
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
  hint?: string;
}) {
  return (
    <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
      <div className="flex items-start gap-3">
        <span
          className={`grid size-9 shrink-0 place-items-center rounded-xl ${tone}`}
        >
          <OpsIcon name={icon} className="size-4" />
        </span>
        <div className="min-w-0">
          <p className="text-xs text-muted">{label}</p>
          <p className="mt-1 text-sm font-semibold break-words text-ink">
            {value}
          </p>
          {hint ? <p className="mt-0.5 text-xs text-muted">{hint}</p> : null}
        </div>
      </div>
    </li>
  );
}

function Place({
  name,
  detail,
  tone,
}: {
  name: string;
  detail?: string;
  tone: string;
}) {
  return (
    <span className="flex min-w-0 gap-2">
      <span
        aria-hidden="true"
        className={`mt-1.5 size-2 shrink-0 rounded-full ${tone}`}
      />
      <span className="min-w-0">
        <span className="block">{name}</span>
        {detail ? (
          <span className="block font-normal text-muted">{detail}</span>
        ) : null}
      </span>
    </span>
  );
}

function Stat({
  icon,
  label,
  value,
  hint,
}: {
  icon: OpsIconName;
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <li className="flex min-w-0 items-center gap-2 rounded-xl border border-border px-3 py-2">
      <OpsIcon name={icon} className="size-4 shrink-0 text-brand" />
      <span className="min-w-0">
        <span className="block text-[11px] text-muted">{label}</span>
        <span className="block text-sm font-semibold break-words text-ink">
          {value}
        </span>
        {hint ? (
          <span className="block text-[11px] text-muted">{hint}</span>
        ) : null}
      </span>
    </li>
  );
}
