"use client";

import { useMemo, useState } from "react";
import { useStoreDetailQuery } from "@/features/stores/hooks";
import {
  storeKybStatusLabel,
  storeKybStatusTone,
  storeSaleStatusLabel,
  storeSaleStatusTone,
} from "@/features/stores/mappers";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  countFormat,
  ExportCsvButton,
  PreviewLink,
  PreviewTabs,
  StatusChip,
  vnd,
} from "@/components/ui/admin-list-ui";
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
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import {
  BackToList,
  DetailHeader,
  DetailSection,
  FieldList,
  SampleNotFound,
  TextAction,
} from "@/components/ui/admin-detail-ui";
import { isForbiddenError } from "@/lib/api/errors";
import { StoreStatementPanel } from "@/features/stores/components/store-statement-panel";

function EmptyPanel({ message = "Chưa có dữ liệu" }: { message?: string }) {
  return (
    <p className="rounded-xl border border-dashed border-border bg-canvas/40 px-3 py-6 text-center text-sm text-muted">
      {message}
    </p>
  );
}

export function StoreDetail({ code }: { code: string }) {
  const [activeTab, setActiveTab] = useState("Tổng quan");
  const {
    data: store,
    isPending,
    isError,
    error,
    refetch,
  } = useStoreDetailQuery(code);
  const forbidden = isError && isForbiddenError(error);

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Cửa hàng", href: "/stores" },
      { label: store?.name || code },
    ],
    [store?.name, code],
  );

  return (
    <div className="min-w-0 space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết cửa hàng"
            description="Tài khoản của bạn không được cấp quyền xem hồ sơ đối tác cửa hàng này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết thông tin cửa hàng. Vui lòng thử lại."
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải chi tiết cửa hàng…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !store ? (
        <SampleNotFound
          crumbs={crumbs}
          heading="Không tìm thấy cửa hàng"
          listHref="/stores"
        />
      ) : (
        <>
          <DetailHeader
            crumbs={crumbs}
            title="Chi tiết cửa hàng"
            subtitle="Thông tin kinh doanh, thực đơn, hiệu suất vận hành và hồ sơ đối tác."
            actions={
              <>
                <BackToList href="/stores" />
                <PreviewLink href="/stores/approvals" tone="ghost">
                  Duyệt cửa hàng
                </PreviewLink>
                <ExportCsvButton
                  tone="brand"
                  filename={`${store.code}-summary.csv`}
                  headers={[
                    "Mã",
                    "Tên",
                    "Khu vực",
                    "Danh mục",
                    "KYB",
                    "Bán hàng",
                  ]}
                  rows={[
                    [
                      store.code,
                      store.name,
                      store.area,
                      store.category,
                      store.kyb ?? "—",
                      store.sale ?? "—",
                    ],
                  ]}
                >
                  <OpsIcon name="download" className="size-4" />
                  Xuất báo cáo
                </ExportCsvButton>
              </>
            }
          />
          <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,22rem)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-4">
              <section
                aria-labelledby="store-profile"
                className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5"
              >
                <div className="flex justify-end">
                  <h2 id="store-profile" className="sr-only">
                    Hồ sơ cửa hàng
                  </h2>
                  {store.sale ? (
                    <StatusChip tone={storeSaleStatusTone(store.sale)} dot>
                      {storeSaleStatusLabel(store.sale)}
                    </StatusChip>
                  ) : (
                    <span className="text-sm text-muted">—</span>
                  )}
                </div>
                <div className="mt-3 flex min-w-0 items-center gap-3">
                  <Avatar
                    letters={store.initials}
                    tone="bg-success/10 text-success"
                    large
                  />
                  <div className="min-w-0">
                    <p className="text-lg font-semibold text-ink">
                      {store.name}
                    </p>
                    <p className="text-sm break-words text-muted">
                      {store.code} · {store.category}
                    </p>
                    <p className="mt-1 text-sm text-muted">
                      {store.rating != null
                        ? `${String(store.rating).replace(".", ",")} · Đánh giá`
                        : "Chưa có dữ liệu đánh giá"}
                    </p>
                  </div>
                </div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {store.kyb ? (
                    <StatusChip tone={storeKybStatusTone(store.kyb)}>
                      KYB · {storeKybStatusLabel(store.kyb)}
                    </StatusChip>
                  ) : (
                    <span className="text-sm text-muted">KYB · —</span>
                  )}
                  <StatusChip tone="brand">Đối tác cửa hàng</StatusChip>
                </div>
                <ul className="mt-4 space-y-2 text-sm text-ink">
                  <li className="flex min-w-0 items-start gap-2">
                    <OpsIcon
                      name="pin"
                      className="mt-0.5 size-4 shrink-0 text-muted"
                    />
                    <span className="break-words">{store.address || store.area}</span>
                  </li>
                  <li className="flex min-w-0 items-start gap-2">
                    <OpsIcon
                      name="clock"
                      className="mt-0.5 size-4 shrink-0 text-muted"
                    />
                    <span className="break-words">
                      Chưa có dữ liệu giờ mở cửa
                    </span>
                  </li>
                </ul>
              </section>
              <DetailSection
                id="store-business"
                title="Thông tin kinh doanh"
                extra={
                  <TextAction>
                    Xem hồ sơ
                    <OpsIcon name="arrowRight" className="size-4" />
                  </TextAction>
                }
              >
                <FieldList
                  rows={[
                    {
                      label: "Đại diện",
                      value: store.ownerName || store.owner || "Chưa có dữ liệu",
                    },
                    {
                      label: "Danh mục",
                      value: store.category || "Chưa có dữ liệu",
                    },
                    {
                      label: "Khu vực",
                      value: store.area || "Chưa có dữ liệu",
                    },
                    {
                      label: "Điện thoại",
                      value: store.phone || "Chưa có dữ liệu",
                    },
                    {
                      label: "Email",
                      value: store.email || "Chưa có dữ liệu",
                    },
                    {
                      label: "Địa chỉ",
                      value: store.address || store.area || "Chưa có dữ liệu",
                    },
                    {
                      label: "Sản phẩm / món",
                      value:
                        store.orders != null
                          ? countFormat.format(store.orders)
                          : "Chưa có dữ liệu",
                    },
                    {
                      label: "Trạng thái bán",
                      value: store.sale ? (
                        <StatusChip tone={storeSaleStatusTone(store.sale)}>
                          {storeSaleStatusLabel(store.sale)}
                        </StatusChip>
                      ) : (
                        "—"
                      ),
                    },
                    {
                      label: "Tự mở lại",
                      value: store.serviceModeUntil
                        ? formatResumeAt(store.serviceModeUntil)
                        : "—",
                    },
                    {
                      label: "Nhận đơn",
                      value: store.acceptSummary ?? "—",
                    },
                    {
                      label: "Thời gian chuẩn bị",
                      value:
                        store.prepMinutes != null
                          ? `${store.prepMinutes} phút`
                          : "—",
                    },
                  ]}
                />
              </DetailSection>
              <DetailSection
                id="store-verification"
                title="Xác thực & an toàn"
                extra={
                  <TextAction>
                    Nhật ký
                    <OpsIcon name="arrowRight" className="size-4" />
                  </TextAction>
                }
              >
                {store.kybDetail ? (
                  <div className="space-y-3">
                    <FieldList
                      rows={[
                        {
                          label: "Trạng thái thẩm định",
                          value: (
                            <StatusChip
                              tone={
                                store.kybDetail.status === "APPROVED"
                                  ? "success"
                                  : "food"
                              }
                            >
                              {store.kybDetail.status === "APPROVED"
                                ? "Đã duyệt KYB"
                                : store.kybDetail.status}
                            </StatusChip>
                          ),
                        },
                        {
                          label: "Người đại diện",
                          value:
                            store.kybDetail.representativeName ||
                            store.ownerName ||
                            "Chưa cập nhật",
                        },
                        {
                          label: "Hình thức",
                          value:
                            store.kybDetail.registrationSubject === "HOUSEHOLD"
                              ? "Hộ kinh doanh"
                              : store.kybDetail.registrationSubject ||
                                "Doanh nghiệp",
                        },
                        {
                          label: "Tài khoản nhận tiền",
                          value: store.kybDetail.bankName
                            ? `${store.kybDetail.bankName} - ${store.kybDetail.bankAccountNumber} (${store.kybDetail.bankAccountHolder})`
                            : "Chưa cập nhật",
                        },
                        {
                          label: "Hồ sơ đính kèm",
                          value: store.kybDetail.documentsWaived
                            ? "Miễn thẩm định tài liệu"
                            : `${store.kybDetail.documentCount} tài liệu đã thẩm định`,
                        },
                      ]}
                    />
                    <div className="mt-3">
                      <PreviewLink
                        href={`/stores/approvals?q=${encodeURIComponent(store.name)}`}
                        tone="neutral"
                      >
                        Xem hàng đợi thẩm định KYB
                      </PreviewLink>
                    </div>
                  </div>
                ) : (
                  <div>
                    <EmptyPanel message="Chưa có dữ liệu checklist KYB." />
                    <div className="mt-3">
                      <PreviewLink href="/stores/approvals" tone="neutral">
                        Xem hàng đợi duyệt
                      </PreviewLink>
                    </div>
                  </div>
                )}
              </DetailSection>
            </div>
            <div className="min-w-0 space-y-4">
              <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
                <Kpi
                  icon="package"
                  tone="bg-brand/10 text-brand"
                  label="Đơn hoàn tất"
                  value={
                    store.stats?.completedOrders != null
                      ? countFormat.format(store.stats.completedOrders)
                      : store.orders != null
                        ? countFormat.format(store.orders)
                        : "0"
                  }
                  hint={
                    store.stats
                      ? "Đơn hoàn thành thực tế"
                      : "Từ hồ sơ cửa hàng"
                  }
                />
                <Kpi
                  icon="star"
                  tone="bg-food/10 text-food"
                  label="Đánh giá trung bình"
                  value={
                    store.stats?.ratingAverage != null
                      ? `${String(store.stats.ratingAverage).replace(".", ",")} / 5`
                      : store.rating != null
                        ? `${String(store.rating).replace(".", ",")} / 5`
                        : "5,0 / 5"
                  }
                  hint={
                    store.stats?.ratingCount
                      ? `Từ ${store.stats.ratingCount} đánh giá`
                      : "Chưa có phản hồi tiêu cực"
                  }
                />
                <Kpi
                  icon="categories"
                  tone="bg-success/10 text-success"
                  label="Sản phẩm đang bán"
                  value={
                    store.items
                      ? countFormat.format(store.items.length)
                      : store.orders != null
                        ? countFormat.format(store.orders)
                        : "0"
                  }
                  hint={
                    store.items
                      ? `${store.items.filter((i) => i.available).length} món có sẵn`
                      : "Số món trên hồ sơ"
                  }
                />
                <Kpi
                  icon="trend"
                  tone="bg-delivery/10 text-delivery"
                  label="Tỷ lệ hoàn tất"
                  value={
                    store.stats?.completionRate != null
                      ? `${Math.round(store.stats.completionRate * 100)}%`
                      : "100%"
                  }
                  hint={
                    store.stats
                      ? `${store.stats.completedOrders}/${store.stats.totalOrders} đơn giao`
                      : "Tỷ lệ chuẩn"
                  }
                />
              </ul>
              <section className="min-w-0">
                <h2 className="sr-only">Tổng quan cửa hàng</h2>
                <PreviewTabs
                  label="Phân hệ cửa hàng"
                  tabs={[
                    "Tổng quan",
                    "Thực đơn",
                    "Đơn hàng",
                    "Đánh giá",
                    "Tài chính",
                    "Nhật ký",
                  ]}
                  current={activeTab}
                  onChange={setActiveTab}
                />
                {activeTab === "Tổng quan" && (
                  <div
                    role="tabpanel"
                    className="mt-4 grid items-start gap-4 xl:grid-cols-2"
                  >
                    <div className="min-w-0 space-y-4">
                      <DetailSection
                        id="store-chart"
                        title="Đơn hoàn tất gần đây"
                      >
                        {store.recentOrders && store.recentOrders.length > 0 ? (
                          <div className="divide-y divide-border">
                            {store.recentOrders.slice(0, 4).map((o) => (
                              <div
                                key={o.id}
                                className="flex items-center justify-between py-2 text-sm"
                              >
                                <div>
                                  <p className="font-semibold text-brand">
                                    {o.code}
                                  </p>
                                  <p className="text-xs text-muted">
                                    {o.customerName} · {o.dropoffLabel}
                                  </p>
                                </div>
                                <div className="text-right">
                                  <p className="font-medium text-ink">
                                    {vnd(o.totalVnd)}
                                  </p>
                                  <p className="text-xs text-muted">
                                    {o.statusLabel}
                                  </p>
                                </div>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <EmptyPanel message="Chưa có dữ liệu đơn hàng." />
                        )}
                      </DetailSection>
                      <DetailSection
                        id="store-products"
                        title="Sản phẩm bán chạy"
                      >
                        {store.items && store.items.length > 0 ? (
                          <div className="divide-y divide-border">
                            {[...store.items]
                              .sort(
                                (a, b) => (b.soldCount ?? 0) - (a.soldCount ?? 0),
                              )
                              .slice(0, 4)
                              .map((item) => (
                                <div
                                  key={item.id}
                                  className="flex items-center justify-between py-2 text-sm"
                                >
                                  <div>
                                    <p className="font-medium text-ink">
                                      {item.name}
                                    </p>
                                    <p className="text-xs text-muted">
                                      Đã bán: {item.soldCount ?? 0} phần
                                    </p>
                                  </div>
                                  <span className="font-semibold text-brand">
                                    {vnd(item.priceVnd)}
                                  </span>
                                </div>
                              ))}
                          </div>
                        ) : (
                          <EmptyPanel message="Chưa có dữ liệu thực đơn / sản phẩm." />
                        )}
                      </DetailSection>
                    </div>
                    <div className="min-w-0 space-y-4">
                      <DetailSection
                        id="store-mix"
                        title="Cơ cấu trạng thái đơn"
                      >
                        {store.stats ? (
                          <div className="space-y-3 py-1">
                            <div className="flex justify-between text-sm">
                              <span className="text-muted">Hoàn thành:</span>
                              <span className="font-semibold text-success">
                                {store.stats.completedOrders} đơn
                              </span>
                            </div>
                            <div className="flex justify-between text-sm">
                              <span className="text-muted">Đã hủy:</span>
                              <span className="font-semibold text-food">
                                {store.stats.cancelledOrders} đơn
                              </span>
                            </div>
                            <div className="flex justify-between border-t border-border pt-2 text-sm font-semibold">
                              <span>Tổng phát sinh:</span>
                              <span>{store.stats.totalOrders} đơn</span>
                            </div>
                          </div>
                        ) : (
                          <EmptyPanel message="Chưa có dữ liệu cơ cấu đơn." />
                        )}
                      </DetailSection>
                      <DetailSection
                        id="store-activity"
                        title="Hoạt động gần đây"
                      >
                        {store.recentOrders && store.recentOrders.length > 0 ? (
                          <div className="divide-y divide-border">
                            {store.recentOrders.slice(0, 3).map((o) => (
                              <div key={o.id} className="py-2 text-sm">
                                <p className="font-medium text-ink">
                                  Đơn {o.code} — {o.statusLabel}
                                </p>
                                <p className="text-xs text-muted">
                                  {o.createdAt}
                                </p>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <EmptyPanel message="Chưa có hoạt động gần đây." />
                        )}
                      </DetailSection>
                    </div>
                  </div>
                )}

                {activeTab === "Thực đơn" && (
                  <div
                    role="tabpanel"
                    className="mt-4 rounded-2xl border border-border bg-white p-4 shadow-sm"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border pb-3">
                      <div>
                        <h3 className="text-base font-semibold text-ink">
                          Danh mục món ăn & thực đơn
                        </h3>
                        <p className="mt-1 text-xs text-muted">
                          {store.items?.length ?? 0} món trên thực đơn quán
                        </p>
                      </div>
                    </div>
                    {store.items && store.items.length > 0 ? (
                      <div className="mt-4">
                        <AdminTableContainer minWidth="min-w-[600px]">
                          <AdminTable caption="Thực đơn quán">
                            <AdminTableHeader>
                              <AdminTableRow>
                                <AdminTableHead>Tên món</AdminTableHead>
                                <AdminTableHead align="right">Giá bán</AdminTableHead>
                                <AdminTableHead align="center">Trạng thái</AdminTableHead>
                                <AdminTableHead align="right">Đã bán</AdminTableHead>
                              </AdminTableRow>
                            </AdminTableHeader>
                            <AdminTableBody>
                              {store.items.map((item) => (
                                <AdminTableRow key={item.id}>
                                  <AdminTableCell className="font-medium text-ink">
                                    {item.name}
                                  </AdminTableCell>
                                  <AdminTableCell align="right" className="font-semibold text-brand tabular-nums">
                                    {vnd(item.priceVnd)}
                                  </AdminTableCell>
                                  <AdminTableCell align="center">
                                    <StatusChip tone={item.available ? "success" : "food"}>
                                      {item.available ? "Đang phục vụ" : "Tạm ngưng"}
                                    </StatusChip>
                                  </AdminTableCell>
                                  <AdminTableCell align="right" className="tabular-nums text-muted">
                                    {item.soldCount ?? 0}
                                  </AdminTableCell>
                                </AdminTableRow>
                              ))}
                            </AdminTableBody>
                          </AdminTable>
                        </AdminTableContainer>
                      </div>
                    ) : (
                      <div className="mt-4">
                        <EmptyPanel message="Chưa có dữ liệu thực đơn." />
                      </div>
                    )}
                  </div>
                )}

                {activeTab === "Đơn hàng" && (
                  <div
                    role="tabpanel"
                    className="mt-4 rounded-2xl border border-border bg-white p-4 shadow-sm"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border pb-3">
                      <div>
                        <h3 className="text-base font-semibold text-ink">
                          Đơn hàng của quán
                        </h3>
                        <p className="text-xs text-muted">
                          Lịch sử các đơn hàng đặt tại cửa hàng này.
                        </p>
                      </div>
                      <PreviewLink href="/food-orders" tone="brand" compact>
                        Xem tất cả đơn DealFood
                      </PreviewLink>
                    </div>
                    {store.recentOrders && store.recentOrders.length > 0 ? (
                      <div className="pt-4">
                        <AdminTableContainer minWidth="min-w-[700px]">
                          <AdminTable caption="Đơn hàng của quán">
                            <AdminTableHeader>
                              <AdminTableRow>
                                <AdminTableHead>Mã đơn</AdminTableHead>
                                <AdminTableHead>Khách hàng</AdminTableHead>
                                <AdminTableHead>Điểm giao</AdminTableHead>
                                <AdminTableHead align="right">Giá trị</AdminTableHead>
                                <AdminTableHead align="center">Trạng thái</AdminTableHead>
                              </AdminTableRow>
                            </AdminTableHeader>
                            <AdminTableBody>
                              {store.recentOrders.map((order) => (
                                <AdminTableRow key={order.id}>
                                  <AdminTableCell className="font-semibold text-brand">
                                    {order.code}
                                  </AdminTableCell>
                                  <AdminTableCell className="font-medium text-ink">
                                    {order.customerName}
                                  </AdminTableCell>
                                  <AdminTableCell className="max-w-[200px] truncate text-muted">
                                    {order.dropoffLabel}
                                  </AdminTableCell>
                                  <AdminTableCell align="right" className="font-semibold text-ink tabular-nums">
                                    {vnd(order.totalVnd)}
                                  </AdminTableCell>
                                  <AdminTableCell align="center">
                                    <StatusChip tone={order.status === "DELIVERED" ? "success" : "food"}>
                                      {order.statusLabel}
                                    </StatusChip>
                                  </AdminTableCell>
                                </AdminTableRow>
                              ))}
                            </AdminTableBody>
                          </AdminTable>
                        </AdminTableContainer>
                      </div>
                    ) : (
                      <div className="pt-4">
                        <EmptyPanel message="Chưa có dữ liệu đơn theo cửa hàng." />
                      </div>
                    )}
                  </div>
                )}

                {activeTab === "Đánh giá" && (
                  <div
                    role="tabpanel"
                    className="mt-4 rounded-2xl border border-border bg-white p-5 shadow-sm"
                  >
                    <h3 className="text-base font-semibold text-ink">
                      Đánh giá từ khách hàng
                    </h3>
                    {store.recentReviews && store.recentReviews.length > 0 ? (
                      <div className="mt-4 divide-y divide-border">
                        {store.recentReviews.map((rev) => (
                          <div key={rev.id} className="py-3 text-sm">
                            <div className="flex items-center justify-between">
                              <span className="font-medium text-ink">
                                {rev.raterName}
                              </span>
                              <span className="font-semibold text-amber-500">
                                {"★".repeat(rev.stars)} ({rev.stars}/5)
                              </span>
                            </div>
                            {rev.comment && (
                              <p className="mt-1 text-muted">{rev.comment}</p>
                            )}
                            <p className="mt-1 text-xs text-muted">
                              {rev.createdAt}
                            </p>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="mt-4">
                        <EmptyPanel message="Chưa có đánh giá nào từ khách hàng." />
                      </div>
                    )}
                  </div>
                )}

                {activeTab === "Tài chính" && (
                  <div
                    role="tabpanel"
                    className="mt-4 rounded-2xl border border-border bg-white p-5 shadow-sm space-y-4"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border pb-4">
                      <div>
                        <h3 className="text-base font-semibold text-ink">
                          Tổng quan tài chính & đối soát
                        </h3>
                        <p className="text-xs text-muted">
                          Sao kê hoa hồng theo ngày (giờ Việt Nam).
                        </p>
                      </div>
                      <PreviewLink href="/settlements" tone="brand" compact>
                        Vào trang đối soát
                      </PreviewLink>
                    </div>
                    <StoreStatementPanel
                      storeId={store.code}
                      storeName={store.name}
                    />
                  </div>
                )}

                {activeTab === "Nhật ký" && (
                  <div
                    role="tabpanel"
                    className="mt-4 rounded-2xl border border-border bg-white p-5 shadow-sm"
                  >
                    <h3 className="text-base font-semibold text-ink">
                      Nhật ký hoạt động cửa hàng
                    </h3>
                    <div className="mt-4">
                      <EmptyPanel />
                    </div>
                  </div>
                )}
              </section>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function Kpi({
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
    <li className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
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
    </li>
  );
}

/** Vietnam wall-clock time of an auto-resume (DEC-PROD-026). */
function formatResumeAt(iso: string): string {
  const at = new Date(iso);
  if (Number.isNaN(at.getTime())) return "—";
  return new Intl.DateTimeFormat("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
  }).format(at);
}
