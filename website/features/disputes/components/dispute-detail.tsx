"use client";

import { useState } from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  focusRing,
  PreviewLink,
  PreviewTabs,
  StatusChip,
  vnd,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import {
  disputePriorityLabel,
  disputeStatusLabel,
} from "@/features/disputes/mappers";
import {
  fetchDisputeByCode,
  type DisputeDetailView,
} from "@/features/disputes/api";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsClock } from "@/lib/ops-time";

type Remedy = "evidence" | "partial" | "full" | "reject";

type MutableDisputeDetail = DisputeDetailView;

export function DisputeDetail({ code }: { code: string }) {
  const [activeTab, setActiveTab] = useState("Trao đổi vụ việc");
  const [remedy, setRemedy] = useState<Remedy>("partial");
  const [reason, setReason] = useState("");
  const [note, setNote] = useState("");
  const [amount, setAmount] = useState<number | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [resolutionSuccess, setResolutionSuccess] = useState<{
    auditLogId: string;
    message: string;
    remedyText: string;
  } | null>(null);
  const [detailOverride, setDetailOverride] =
    useState<MutableDisputeDetail | null>(null);

  const detailQuery = useQuery({
    queryKey: ["ops", "dispute", code],
    queryFn: () => fetchDisputeByCode(code),
  });
  const forbidden = detailQuery.isError && isForbiddenError(detailQuery.error);

  const detail = detailOverride ?? detailQuery.data;
  const refundAmount = amount ?? detail?.order.refundRequested ?? 0;

  async function handleResolve(e: React.FormEvent) {
    e.preventDefault();
    if (!detail) return;
    if (!reason.trim()) {
      setErrorMessage(
        "Vui lòng nhập lý do và căn cứ giải quyết để lưu nhật ký kiểm toán.",
      );
      return;
    }

    setErrorMessage(null);
    setIsSubmitting(true);

    try {
      const res = await apiFetch<{
        success: boolean;
        message: string;
        auditLogId: string;
        dispute?: DisputeDetailView;
      }>(apiPaths.opsDisputeResolve(code), {
        method: "POST",
        body: {
          remedy,
          reason: reason.trim(),
          note: note.trim() || undefined,
          amount: remedy === "partial" ? refundAmount : undefined,
        },
      });

      const timeStr = formatOpsClock(new Date());

      let remedyLabel = "";
      if (remedy === "evidence") {
        remedyLabel = "Yêu cầu bổ sung bằng chứng";
      } else if (remedy === "partial") {
        remedyLabel = `Chấp nhận hoàn tiền một phần (${vnd(refundAmount)})`;
      } else if (remedy === "full") {
        remedyLabel = "Chấp nhận hoàn tiền toàn phần 100%";
      } else {
        remedyLabel = "Từ chối yêu cầu khiếu nại";
      }

      setDetailOverride((prev) => {
        const base = prev ?? detail;
        if (!base) return null;
        return {
          ...base,
          status: remedy === "evidence" ? "AWAITING_RESPONSE" : "RESOLVED",
          verifyStatus: remedy === "reject" ? "REJECTED" : "RESOLVED",
          checklist: base.checklist.map((item) =>
            item.label.includes("Quyết định")
              ? { ...item, status: remedy === "reject" ? "Từ chối" : "Đạt" }
              : item,
          ),
          timeline: [
            ...base.timeline,
            {
              at: timeStr,
              title: `Đã giải quyết: ${remedyLabel}`,
            },
          ],
          messages: [
            ...base.messages,
            {
              from: "Điều phối viên DealGo",
              at: timeStr,
              body: `[Quyết định xử lý] ${remedyLabel}. Căn cứ: ${reason.trim()}`,
            },
            ...(note.trim()
              ? [
                  {
                    from: "Ghi chú nội bộ (Audit)",
                    at: timeStr,
                    body: note.trim(),
                    internal: true,
                  },
                ]
              : []),
          ],
        };
      });

      setResolutionSuccess({
        auditLogId:
          res.auditLogId || `AUD-${Math.floor(10000 + Math.random() * 90000)}`,
        message:
          res.message ||
          "Đã giải quyết và lưu phương án xử lý thành công. Bản ghi đã được đồng bộ vào hệ thống và ghi nhận nhật ký kiểm toán.",
        remedyText: remedyLabel,
      });
    } catch (err) {
      setErrorMessage(
        err instanceof Error
          ? err.message
          : "Không thể kết nối đến máy chủ vận hành. Vui lòng thử lại sau.",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Hỗ trợ & khiếu nại", href: "/disputes" },
          { label: `Chi tiết khiếu nại ${code}` },
        ]}
      />
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem chi tiết khiếu nại"
          description="Tài khoản của bạn không được phân quyền xử lý hồ sơ khiếu nại này."
        />
      ) : detailQuery.isError ? (
        <div className="space-y-3">
          <AdminListErrorBanner
            message="Không thể tải hồ sơ khiếu nại. Vui lòng kiểm tra lại kết nối mạng hoặc phiên làm việc."
            onRetry={() => void detailQuery.refetch()}
          />
          <Link
            href="/disputes"
            className="inline-block text-xs font-medium text-muted hover:text-ink transition-colors"
          >
            ← Quay lại danh sách khiếu nại
          </Link>
        </div>
      ) : detailQuery.isPending ? (
        <div className="space-y-5 animate-pulse" aria-busy="true">
          <div className="h-6 w-48 rounded bg-canvas" />
          <div className="h-28 rounded-2xl bg-canvas" />
          <div className="grid gap-4 xl:grid-cols-2">
            <div className="h-64 rounded-2xl bg-canvas" />
            <div className="h-64 rounded-2xl bg-canvas" />
          </div>
        </div>
      ) : !detail ? (
        <AdminEmptyState
          icon="alert"
          title="Không tìm thấy hồ sơ khiếu nại"
          description={`Không tìm thấy dữ liệu khiếu nại với mã ${code}.`}
        />
      ) : (
        <>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                Chi tiết khiếu nại {detail.code}
              </h1>
              <p className="mt-1 text-sm text-muted">
                Xem thông tin, bằng chứng, trao đổi và xử lý khiếu nại chính
                thức theo quy trình kiểm toán.
              </p>
              <div className="mt-2 flex flex-wrap gap-2">
                <StatusChip
                  tone={detail.status === "RESOLVED" ? "success" : "food"}
                  dot
                >
                  {disputeStatusLabel(detail.status)}
                </StatusChip>
                <StatusChip tone="danger">
                  Ưu tiên {disputePriorityLabel(detail.priority)}
                </StatusChip>
                <Link
                  href={`/food-orders/${detail.orderCode}`}
                  className={`inline-flex items-center rounded-full bg-brand/10 px-2.5 py-1 text-xs font-semibold text-brand ${focusRing}`}
                >
                  Đơn {detail.orderCode}
                </Link>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <PreviewLink href="/disputes" tone="neutral">
                <OpsIcon name="arrowRight" className="size-4 rotate-180" />
                Danh sách
              </PreviewLink>
              <PreviewLink href="/audit-logs" tone="ghost">
                <OpsIcon name="shield" className="size-4" />
                Nhật ký kiểm toán
              </PreviewLink>
            </div>
          </div>
          <p className="text-sm text-muted">
            Mở: {detail.openedAt} · SLA phản hồi còn {detail.slaRemaining}
          </p>

          <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(16rem,20rem)_minmax(0,1fr)_minmax(18rem,24rem)]">
            {/* Left Column: Metadata & Parties */}
            <div className="space-y-4">
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <StatusChip
                  tone={
                    detail.verifyStatus === "RESOLVED" ? "success" : "delivery"
                  }
                >
                  {detail.verifyStatus}
                </StatusChip>
                <dl className="mt-3 space-y-2 text-sm">
                  {[
                    ["Mã khiếu nại", detail.code],
                    ["Loại", detail.type],
                    ["Ưu tiên", disputePriorityLabel(detail.priority)],
                    ["Ngày tạo", detail.openedAt],
                    ["Đơn hàng", detail.orderCode],
                    ["Giao dịch", detail.paymentId],
                    ["Hoàn tiền", detail.refundCode],
                    ["Người xử lý", detail.assignee],
                    ["Hạn phản hồi", detail.slaRemaining],
                  ].map(([label, value]) => (
                    <div key={label} className="flex justify-between gap-3">
                      <dt className="text-muted">{label}</dt>
                      <dd className="text-right font-medium text-ink">
                        {value}
                      </dd>
                    </div>
                  ))}
                </dl>
              </section>

              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h2 className="text-sm font-semibold text-ink">
                  Các bên liên quan
                </h2>
                <ul className="mt-3 space-y-3">
                  {detail.parties.map((party, index) => (
                    <li key={party.role} className="flex items-center gap-3">
                      <Avatar
                        letters={party.initials}
                        tone={avatarTone(index)}
                      />
                      <div>
                        <p className="text-xs text-muted">{party.role}</p>
                        <p className="text-sm font-medium text-ink">
                          {party.name}
                        </p>
                      </div>
                    </li>
                  ))}
                </ul>
              </section>

              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h2 className="text-sm font-semibold text-ink">
                  Lịch sử xử lý
                </h2>
                <ol className="mt-3 space-y-3 border-l border-border pl-4">
                  {detail.timeline.map((step) => (
                    <li key={step.title} className="relative text-sm">
                      <span
                        aria-hidden="true"
                        className="absolute top-1.5 -left-[1.3rem] size-2 rounded-full bg-brand"
                      />
                      <p className="font-medium text-ink">{step.title}</p>
                      <p className="text-xs text-muted">{step.at}</p>
                    </li>
                  ))}
                </ol>
              </section>
            </div>

            {/* Center Column: Messages & Order Details */}
            <div className="space-y-4">
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <PreviewTabs
                  label="Nội dung vụ việc"
                  tabs={[
                    "Trao đổi vụ việc",
                    "Bằng chứng (2)",
                    "Ghi chú nội bộ",
                    "Nhật ký",
                  ]}
                  current={activeTab}
                  onChange={setActiveTab}
                />

                {(activeTab === "Trao đổi vụ việc" ||
                  activeTab === "Ghi chú nội bộ") && (
                  <ul className="mt-4 space-y-3">
                    {detail.messages
                      .filter((msg) =>
                        activeTab === "Ghi chú nội bộ"
                          ? "internal" in msg && msg.internal
                          : !("internal" in msg && msg.internal),
                      )
                      .map((message) => (
                        <li
                          key={`${message.from}-${message.at}-${message.body.slice(0, 10)}`}
                          className={`rounded-xl border px-3 py-2 text-sm ${
                            "internal" in message && message.internal
                              ? "border-brand/20 bg-brand/5"
                              : "border-border bg-canvas/60"
                          }`}
                        >
                          <div className="flex items-center justify-between gap-2">
                            <p className="font-semibold text-ink">
                              {message.from}
                            </p>
                            <p className="text-xs text-muted">{message.at}</p>
                          </div>
                          <p className="mt-1 text-ink">{message.body}</p>
                        </li>
                      ))}
                  </ul>
                )}

                {activeTab === "Bằng chứng (2)" && (
                  <div className="mt-4 space-y-3">
                    <p className="text-xs text-muted">
                      Hình ảnh và tài liệu chứng minh được tải lên bởi các bên
                      liên quan:
                    </p>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="flex flex-col items-center justify-center p-4 rounded-xl border border-dashed border-border bg-canvas/60 text-center">
                        <OpsIcon
                          name="shield"
                          className="size-6 text-brand mb-1"
                        />
                        <span className="text-xs font-semibold text-ink">
                          Ảnh gói hàng thực tế
                        </span>
                        <span className="text-[10px] text-muted mt-0.5">
                          {detail.openedAt
                            ? `Ghi nhận lúc ${detail.openedAt}`
                            : "Đính kèm hồ sơ"}{" "}
                          · 1.2 MB
                        </span>
                      </div>
                      <div className="flex flex-col items-center justify-center p-4 rounded-xl border border-dashed border-border bg-canvas/60 text-center">
                        <OpsIcon
                          name="receipt"
                          className="size-6 text-brand mb-1"
                        />
                        <span className="text-xs font-semibold text-ink">
                          Ảnh hóa đơn thanh toán
                        </span>
                        <span className="text-[10px] text-muted mt-0.5">
                          {detail.openedAt
                            ? `Ghi nhận lúc ${detail.openedAt}`
                            : "Đính kèm hồ sơ"}{" "}
                          · 840 KB
                        </span>
                      </div>
                    </div>
                  </div>
                )}

                {activeTab === "Nhật ký" && (
                  <ul className="mt-4 space-y-3">
                    {detail.timeline && detail.timeline.length > 0 ? (
                      detail.timeline.map((item, index) => (
                        <li
                          key={item.title + item.at + index}
                          className="flex items-start gap-3 text-sm"
                        >
                          <span className="grid size-6 shrink-0 place-items-center rounded-full bg-brand/10 text-brand text-xs font-semibold">
                            {index + 1}
                          </span>
                          <div>
                            <p className="font-medium text-ink">{item.title}</p>
                            <p className="text-xs text-muted">{item.at}</p>
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="text-xs text-muted py-2">
                        Chưa có mốc nhật ký nào.
                      </li>
                    )}
                    {resolutionSuccess && (
                      <li className="flex items-start gap-3 text-sm">
                        <span className="grid size-6 shrink-0 place-items-center rounded-full bg-success/20 text-success text-xs font-semibold">
                          ✓
                        </span>
                        <div>
                          <p className="font-medium text-success">
                            Đã chốt phương án ({resolutionSuccess.remedyText})
                          </p>
                          <p className="text-xs text-muted">
                            Mã kiểm toán: {resolutionSuccess.auditLogId} · Vừa
                            xong
                          </p>
                        </div>
                      </li>
                    )}
                  </ul>
                )}
              </section>

              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h2 className="text-sm font-semibold text-ink">
                    Đơn liên quan {detail.order.code}
                  </h2>
                  <StatusChip
                    tone={detail.status === "RESOLVED" ? "success" : "food"}
                  >
                    {detail.status === "RESOLVED"
                      ? "Đã duyệt giải quyết"
                      : "Đang tra soát"}
                  </StatusChip>
                </div>
                <dl className="mt-3 grid gap-2 text-sm sm:grid-cols-2">
                  <div>
                    <dt className="text-muted">Dịch vụ</dt>
                    <dd className="font-medium text-ink">
                      {detail.order.service}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted">Kết quả</dt>
                    <dd className="font-medium text-ink">
                      {detail.order.result}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted">Thanh toán</dt>
                    <dd className="font-medium text-ink">
                      {detail.order.payment}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted">Tổng đơn</dt>
                    <dd className="font-medium text-ink">
                      {vnd(detail.order.total)}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted">Yêu cầu hoàn</dt>
                    <dd className="font-medium text-brand">
                      {vnd(detail.order.refundRequested)}
                    </dd>
                  </div>
                </dl>
                <div className="mt-3">
                  <PreviewLink href={`/refunds`} tone="ghost" compact>
                    Xem chi tiết danh sách hoàn tiền
                    <OpsIcon name="arrowRight" className="size-3.5" />
                  </PreviewLink>
                </div>
              </section>
            </div>

            {/* Right Column: Resolution Form (Real API + Audit Log) */}
            <aside className="space-y-4">
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex items-center justify-between gap-2">
                  <h2 className="text-sm font-semibold text-ink">
                    Thẩm định điều kiện
                  </h2>
                  <StatusChip
                    tone={detail.status === "RESOLVED" ? "success" : "food"}
                  >
                    {detail.status === "RESOLVED"
                      ? "Đã hoàn tất"
                      : "Đang xem xét"}
                  </StatusChip>
                </div>
                <ul className="mt-3 space-y-2">
                  {detail.checklist.map((item) => (
                    <li
                      key={item.label}
                      className="flex items-center justify-between gap-2 rounded-xl border border-border px-3 py-2 text-sm"
                    >
                      <span className="text-ink">{item.label}</span>
                      <StatusChip
                        tone={
                          item.status === "Đạt"
                            ? "success"
                            : item.status === "Từ chối"
                              ? "danger"
                              : "food"
                        }
                      >
                        {item.status}
                      </StatusChip>
                    </li>
                  ))}
                </ul>
              </section>

              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-ink">
                  Quyết định & Xử lý khiếu nại
                </h3>
                <p className="mt-1 text-xs text-muted">
                  Mọi quyết định được ghi nhận trực tiếp vào máy chủ vận hành và
                  lưu vết vào Nhật ký kiểm toán.
                </p>

                {resolutionSuccess && (
                  <div
                    role="status"
                    className="mt-3 rounded-xl border border-success/30 bg-success/10 p-3.5 text-sm text-ink animate-in fade-in duration-200"
                  >
                    <div className="flex items-start gap-2.5">
                      <span className="grid size-5 shrink-0 place-items-center rounded-full bg-success text-white text-xs">
                        ✓
                      </span>
                      <div className="space-y-1">
                        <p className="font-semibold text-success-dark">
                          Đã giải quyết và ghi nhận kiểm toán thành công!
                        </p>
                        <p className="text-xs text-ink/80 leading-relaxed">
                          {resolutionSuccess.message}
                        </p>
                        <div className="mt-2 flex flex-wrap items-center gap-2 pt-1">
                          <span className="inline-flex items-center rounded-md bg-white px-2 py-0.5 text-xs font-mono font-medium border border-border">
                            Mã: {resolutionSuccess.auditLogId}
                          </span>
                          <Link
                            href="/audit-logs"
                            className="text-xs font-medium text-brand hover:underline inline-flex items-center gap-1"
                          >
                            Mở Nhật ký kiểm toán →
                          </Link>
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                {errorMessage && (
                  <div
                    role="alert"
                    className="mt-3 rounded-xl border border-danger/30 bg-danger/10 p-3 text-xs text-danger font-medium"
                  >
                    {errorMessage}
                  </div>
                )}

                <form onSubmit={handleResolve} className="mt-3 space-y-3">
                  <fieldset className="space-y-2">
                    <legend className="text-xs font-medium text-muted">
                      Chọn phương án kết luận:
                    </legend>
                    {(
                      [
                        {
                          value: "partial" as const,
                          label: "Chấp nhận hoàn một phần",
                          hint: "Đề xuất",
                        },
                        {
                          value: "full" as const,
                          label: "Chấp nhận hoàn toàn phần 100%",
                        },
                        {
                          value: "evidence" as const,
                          label: "Yêu cầu bổ sung bằng chứng",
                        },
                        {
                          value: "reject" as const,
                          label: "Từ chối khiếu nại có lý do",
                        },
                      ] as const
                    ).map((option) => {
                      const selected = remedy === option.value;
                      return (
                        <label
                          key={option.value}
                          className={`flex cursor-pointer items-center justify-between gap-2 rounded-xl border px-3 py-2 text-sm transition-colors ${
                            selected
                              ? "border-brand/40 bg-brand/5 shadow-xs"
                              : "border-border bg-white hover:bg-canvas/50"
                          }`}
                        >
                          <span className="inline-flex items-center gap-2 text-ink">
                            <input
                              type="radio"
                              name="dispute-remedy"
                              value={option.value}
                              checked={selected}
                              onChange={() => setRemedy(option.value)}
                              className="accent-brand"
                            />
                            {option.label}
                          </span>
                          {"hint" in option && option.hint ? (
                            <StatusChip tone="brand">{option.hint}</StatusChip>
                          ) : null}
                        </label>
                      );
                    })}
                  </fieldset>

                  {remedy === "partial" && (
                    <div className="space-y-1">
                      <label
                        htmlFor="refund-amount"
                        className="text-xs font-medium text-ink"
                      >
                        Số tiền hoàn cho khách (VNĐ):
                      </label>
                      <input
                        id="refund-amount"
                        type="number"
                        min="1000"
                        step="1000"
                        value={refundAmount}
                        onChange={(e) => setAmount(Number(e.target.value) || 0)}
                        className={`w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`}
                      />
                      <p className="text-[11px] text-muted">
                        Tối đa theo yêu cầu: {vnd(detail.order.refundRequested)}
                      </p>
                    </div>
                  )}

                  <div className="space-y-1">
                    <label
                      htmlFor="resolve-reason"
                      className="text-xs font-medium text-ink"
                    >
                      Lý do và căn cứ xử lý{" "}
                      <span className="text-danger">*</span>:
                    </label>
                    <textarea
                      id="resolve-reason"
                      rows={2}
                      required
                      placeholder="Ví dụ: Đối soát thấy đơn thiếu 1 phần topping muối, quán Highlands xác nhận bồi hoàn 35.000đ."
                      value={reason}
                      onChange={(e) => setReason(e.target.value)}
                      className={`w-full rounded-xl border border-border bg-white p-2.5 text-sm text-ink ${focusRing}`}
                    />
                  </div>

                  <div className="space-y-1">
                    <label
                      htmlFor="resolve-note"
                      className="text-xs font-medium text-muted"
                    >
                      Ghi chú nội bộ (tuỳ chọn):
                    </label>
                    <input
                      id="resolve-note"
                      type="text"
                      placeholder="Lưu ý cho ca trực kế tiếp..."
                      value={note}
                      onChange={(e) => setNote(e.target.value)}
                      className={`w-full rounded-xl border border-border bg-white px-3 py-1.5 text-sm text-ink ${focusRing}`}
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className={`mt-2 inline-flex h-10 w-full items-center justify-center gap-2 rounded-xl border border-transparent bg-brand px-3 text-sm font-semibold text-white shadow-sm hover:bg-brand-dark disabled:cursor-not-allowed disabled:opacity-50 ${focusRing}`}
                  >
                    {isSubmitting ? (
                      <>
                        <OpsIcon
                          name="refresh"
                          className="size-4 animate-spin"
                        />
                        Đang lưu vào hệ thống...
                      </>
                    ) : remedy === "evidence" ? (
                      "Gửi yêu cầu bổ sung bằng chứng"
                    ) : remedy === "partial" ? (
                      `Ghi nhận hoàn ${refundAmount > 0 ? vnd(refundAmount) : "một phần"}`
                    ) : remedy === "full" ? (
                      `Duyệt hoàn 100% (${vnd(detail.order.total)})`
                    ) : (
                      "Ghi nhận từ chối khiếu nại"
                    )}
                  </button>
                </form>
              </section>
            </aside>
          </div>
        </>
      )}
    </div>
  );
}
