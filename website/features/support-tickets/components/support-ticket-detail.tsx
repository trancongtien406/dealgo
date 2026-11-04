"use client";

import Link from "next/link";
import { useState } from "react";

import { StatusChip, focusRing } from "@/components/ui/admin-list-ui";
import { BackToList, DetailHeader, DetailSection, FieldList } from "@/components/ui/admin-detail-ui";
import { SearchSelect } from "@/components/ui/search-select";
import { ChatReviewButton } from "@/features/chat-review/components/chat-review-button";

import {
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminPageSkeleton,
} from "@/components/ui/admin-state-ui";
import { toast } from "@/components/ui/toast";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import {
  usePatchSupportTicketMutation,
  useReplySupportTicketMutation,
  useSupportTicketQuery,
} from "@/features/support-tickets/hooks";
import { formatBytes } from "@/features/kyc/partner-review";
import {
  formatTicketTime,
  nextStatuses,
  supportAttachmentUrl,
  relatedLink,
  requesterLine,
  supportCategoryLabel,
  supportPriorityLabel,
  supportPriorityTone,
  supportRoleLabel,
  supportStatusLabel,
  supportStatusTone,
} from "@/features/support-tickets/mappers";
import type {
  SupportTicketPriority,
  SupportTicketStatus,
} from "@/features/support-tickets/types";

const CRUMBS = [
  { label: "Trang chủ", href: "/overview" },
  { label: "Yêu cầu hỗ trợ", href: "/support-tickets" },
];

const fieldClass = `w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`;

function errorText(error: unknown, fallback: string): string {
  return error instanceof Error && error.message ? error.message : fallback;
}

export function SupportTicketDetail({ id }: { id: string }) {
  const { data: ticket, isPending, isError, error, refetch } = useSupportTicketQuery(id);
  const patch = usePatchSupportTicketMutation(id);
  const reply = useReplySupportTicketMutation(id);
  const [replyBody, setReplyBody] = useState("");
  const [nextStatus, setNextStatus] = useState<SupportTicketStatus | "">("");
  const [nextPriority, setNextPriority] = useState<SupportTicketPriority | "">("");
  const [reason, setReason] = useState("");

  if (isPending) {
    return <AdminPageSkeleton />;
  }
  if (isError || !ticket) {
    if (isForbiddenError(error)) {
      return (
        <AdminForbiddenState
          title="Không có quyền xem yêu cầu hỗ trợ"
          description="Tài khoản Ops hiện tại chưa được cấp quyền vận hành."
        />
      );
    }
    const notFound = error instanceof ApiError && (error.status === 404 || error.status === 400);
    return (
      <div className="space-y-4">
        <BackToList href="/support-tickets" />
        <AdminListErrorBanner
          message={notFound ? "Không tìm thấy yêu cầu hỗ trợ này." : errorText(error, "Không tải được yêu cầu.")}
          onRetry={notFound ? undefined : () => void refetch()}
        />
      </div>
    );
  }

  const who = requesterLine(ticket);
  const related = relatedLink(ticket);
  const closed = ticket.status === "CLOSED";
  const canSave =
    reason.trim().length >= 3 &&
    ((nextStatus !== "" && nextStatus !== ticket.status) ||
      (nextPriority !== "" && nextPriority !== ticket.priority));

  const sendReply = () => {
    const body = replyBody.trim();
    if (!body) return;
    reply.mutate(body, {
      onSuccess: () => {
        setReplyBody("");
        toast.success("Đã gửi phản hồi cho người dùng.");
      },
      onError: (err) => toast.error(errorText(err, "Không gửi được phản hồi.")),
    });
  };

  const saveStatus = () => {
    patch.mutate(
      {
        ...(nextStatus && nextStatus !== ticket.status ? { status: nextStatus } : {}),
        ...(nextPriority && nextPriority !== ticket.priority ? { priority: nextPriority } : {}),
        reason: reason.trim(),
      },
      {
        onSuccess: () => {
          setNextStatus("");
          setNextPriority("");
          setReason("");
          toast.success("Đã cập nhật yêu cầu hỗ trợ.");
        },
        onError: (err) => toast.error(errorText(err, "Không cập nhật được yêu cầu.")),
      },
    );
  };

  return (
    <div className="space-y-5">
      <DetailHeader
        crumbs={[...CRUMBS, { label: ticket.code }]}
        title={ticket.subject}
        subtitle={`${ticket.code} · Tạo lúc ${formatTicketTime(ticket.createdAt)}`}
        actions={
          <>
            <StatusChip tone={supportPriorityTone[ticket.priority]}>
              Ưu tiên: {supportPriorityLabel[ticket.priority]}
            </StatusChip>
            <StatusChip tone={supportStatusTone[ticket.status]} dot>
              {supportStatusLabel[ticket.status]}
            </StatusChip>
            <BackToList href="/support-tickets" />
            {ticket.relatedId && ticket.relatedType ? (
              <ChatReviewButton
                kind={ticket.relatedType === "RIDE" ? "ride" : "food"}
                id={ticket.relatedId}
                ticketId={ticket.id}
                partnerLabel={ticket.relatedType === "RIDE" ? "Tài xế" : "Tài xế/Cửa hàng"}
              />
            ) : null}
          </>
        }
      />

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <DetailSection id="support-thread" title="Trao đổi">
          <ol className="space-y-3" aria-label="Lịch sử trao đổi">
            {(ticket.messages ?? []).map((message) => {
              const staff = message.author === "STAFF";
              return (
                <li key={message.id} className={`flex ${staff ? "justify-end" : "justify-start"}`}>
                  <div
                    className={`max-w-[85%] rounded-2xl px-4 py-3 text-sm ${
                      staff ? "bg-brand/10 text-ink" : "bg-canvas text-ink"
                    }`}
                  >
                    <p className="text-xs font-semibold text-muted">
                      {staff ? "Hỗ trợ DealGo" : who.name} · {formatTicketTime(message.createdAt)}
                    </p>
                    <p className="mt-1 whitespace-pre-wrap break-words">{message.body}</p>
                    {(message.attachments ?? []).length > 0 ? (
                      <ul className="mt-2 flex flex-wrap gap-2">
                        {(message.attachments ?? []).map((attachment) => {
                          const url = supportAttachmentUrl(ticket.id, message.id, attachment.index);
                          const name =
                            attachment.label ?? `Tệp ${attachment.index + 1}`;
                          return (
                            <li key={attachment.index}>
                              <a
                                href={url}
                                target="_blank"
                                rel="noreferrer"
                                className="block overflow-hidden rounded-lg border border-border bg-white text-xs text-ink"
                              >
                                {attachment.contentType.startsWith("image/") ? (
                                  // eslint-disable-next-line @next/next/no-img-element -- same-origin BFF stream
                                  <img
                                    src={url}
                                    alt={name}
                                    loading="lazy"
                                    className="h-20 w-28 object-cover"
                                  />
                                ) : null}
                                <span className="block px-2 py-1">
                                  {name} · {formatBytes(attachment.sizeBytes)}
                                </span>
                              </a>
                            </li>
                          );
                        })}
                      </ul>
                    ) : null}
                  </div>
                </li>
              );
            })}
          </ol>

          <div className="mt-5 border-t border-border pt-4">
            {closed ? (
              <p className="text-sm text-muted">
                Yêu cầu đã đóng. Mở lại (chuyển &quot;Đang xử lý&quot;) để tiếp tục trao đổi.
              </p>
            ) : ticket.channel === "WEB" ? (
              <p className="mb-3 rounded-xl bg-canvas p-3 text-xs text-muted">
                Yêu cầu từ website: người gửi không có tài khoản ứng dụng nên sẽ không thấy phản
                hồi này. Hãy liên hệ trực tiếp qua {who.contact} và ghi lại kết quả tại đây.
              </p>
            ) : null}
            {!closed ? (
              <>
                <label htmlFor="support-reply" className="text-xs font-medium text-muted">
                  Phản hồi với tư cách Hỗ trợ DealGo
                </label>
                <textarea
                  id="support-reply"
                  rows={4}
                  maxLength={5000}
                  value={replyBody}
                  onChange={(event) => setReplyBody(event.target.value)}
                  placeholder="Nhập nội dung phản hồi…"
                  className={`mt-1.5 py-2 ${fieldClass}`}
                />
                <div className="mt-2 flex justify-end">
                  <button
                    type="button"
                    disabled={!replyBody.trim() || reply.isPending}
                    onClick={sendReply}
                    className={`inline-flex h-10 items-center rounded-xl bg-brand px-4 text-sm font-semibold text-white hover:bg-brand/90 disabled:opacity-50 ${focusRing}`}
                  >
                    {reply.isPending ? "Đang gửi…" : "Gửi phản hồi"}
                  </button>
                </div>
              </>
            ) : null}
          </div>
        </DetailSection>

        <div className="space-y-5">
          <DetailSection id="support-info" title="Thông tin yêu cầu">
            <FieldList
              rows={[
                { label: "Nhóm vấn đề", value: supportCategoryLabel[ticket.category] },
                { label: "Kênh", value: ticket.channel === "APP" ? "Ứng dụng" : "Website" },
                {
                  label: "Vai trò",
                  value: supportRoleLabel[ticket.requesterRole] ?? ticket.requesterRole,
                },
                { label: "Người gửi", value: who.name },
                { label: "Liên hệ", value: who.contact },
                {
                  label: "Liên quan",
                  value: related ? (
                    related.href ? (
                      <Link href={related.href} className="text-brand hover:underline">
                        {related.label}
                      </Link>
                    ) : (
                      related.label
                    )
                  ) : (
                    "—"
                  ),
                },
                { label: "Hoạt động cuối", value: formatTicketTime(ticket.lastMessageAt) },
                ...(ticket.resolvedAt
                  ? [{ label: "Giải quyết lúc", value: formatTicketTime(ticket.resolvedAt) }]
                  : []),
                ...(ticket.closedAt
                  ? [{ label: "Đóng lúc", value: formatTicketTime(ticket.closedAt) }]
                  : []),
              ]}
            />
          </DetailSection>

          <DetailSection id="support-status" title="Cập nhật trạng thái">
            <div className="space-y-3">
              <div>
                <SearchSelect
                  label="Trạng thái mới"
                  icon="sliders"
                  value={nextStatus || null}
                  options={nextStatuses(ticket.status).map((value) => ({
                    value,
                    label: supportStatusLabel[value],
                  }))}
                  placeholder={`Giữ nguyên (${supportStatusLabel[ticket.status]})`}
                  clearLabel={`Giữ nguyên (${supportStatusLabel[ticket.status]})`}
                  onChange={(val) => setNextStatus((val ?? "") as SupportTicketStatus | "")}
                />
              </div>
              <div>
                <SearchSelect
                  label="Mức ưu tiên"
                  icon="sliders"
                  value={nextPriority || null}
                  options={(Object.keys(supportPriorityLabel) as SupportTicketPriority[])
                    .filter((value) => value !== ticket.priority)
                    .map((value) => ({
                      value,
                      label: supportPriorityLabel[value],
                    }))}
                  placeholder={`Giữ nguyên (${supportPriorityLabel[ticket.priority]})`}
                  clearLabel={`Giữ nguyên (${supportPriorityLabel[ticket.priority]})`}
                  onChange={(val) => setNextPriority((val ?? "") as SupportTicketPriority | "")}
                />
              </div>
              <div>
                <label htmlFor="support-reason" className="text-xs font-medium text-muted">
                  Lý do (ghi nhật ký kiểm toán)
                </label>
                <input
                  id="support-reason"
                  type="text"
                  maxLength={500}
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  placeholder="Ví dụ: Đã hoàn phụ phí cho khách"
                  className={`mt-1.5 h-10 ${fieldClass}`}
                />
              </div>
              <button
                type="button"
                disabled={!canSave || patch.isPending}
                onClick={saveStatus}
                className={`inline-flex h-10 w-full items-center justify-center rounded-xl border border-border bg-white text-sm font-semibold text-ink hover:bg-canvas disabled:opacity-50 ${focusRing}`}
              >
                {patch.isPending ? "Đang lưu…" : "Lưu thay đổi"}
              </button>
            </div>
          </DetailSection>
        </div>
      </div>
    </div>
  );
}
