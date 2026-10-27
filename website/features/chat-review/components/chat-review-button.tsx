"use client";

import { useId, useState } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import { OpsIcon } from "@/components/ui/ops-icons";
import { OpsInterveneActionButton } from "@/components/ui/ops-intervene-dialog";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";
import { reviewChat, type ChatReviewResult } from "../api";

type Props = {
  kind: "ride" | "food";
  id: string;
  ticketId?: string;
  partnerLabel: string;
};

/** DEC-PROD-056: reason → audited server-side decrypt → read-only transcript. */
export function ChatReviewButton({ kind, id, ticketId, partnerLabel }: Props) {
  const titleId = useId();
  const [asking, setAsking] = useState(false);
  const [result, setResult] = useState<ChatReviewResult | null>(null);

  return (
    <>
      <OpsInterveneActionButton tone="brand" onClick={() => setAsking(true)}>
        <OpsIcon name="eye" className="size-4" />
        Xem tin nhắn
      </OpsInterveneActionButton>
      <ReasonDialog
        open={asking}
        title="Xem tin nhắn"
        description="Mỗi lần xem được ghi vào nhật ký kiểm toán."
        confirmLabel="Xem"
        testId="chat-review-dialog"
        onClose={() => setAsking(false)}
        onSubmit={async (reason) => {
          try {
            setResult(await reviewChat({ kind, id, reason, ...(ticketId ? { ticketId } : {}) }));
          } catch (error) {
            if (isForbiddenError(error)) {
              throw new Error("Bạn không có quyền xem tin nhắn.");
            }
            throw new Error(error instanceof ApiError ? error.message : "Không tải được tin nhắn.");
          }
        }}
      />
      {result ? (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-4 sm:items-center"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) {
              setResult(null);
            }
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            data-testid="chat-review-transcript"
            className="flex max-h-[80vh] w-full max-w-lg flex-col rounded-2xl border border-border bg-white p-4 shadow-lg"
          >
            <div className="flex items-center justify-between gap-2">
              <h2 id={titleId} className="text-base font-semibold text-ink">
                Tin nhắn
              </h2>
              <button
                type="button"
                aria-label="Đóng"
                onClick={() => setResult(null)}
                className={`rounded-lg p-1 text-muted hover:text-ink ${focusRing}`}
              >
                <OpsIcon name="close" className="size-4" />
              </button>
            </div>
            <p className="mt-1 text-xs text-muted">Lưu {result.retentionDays} ngày</p>
            {result.messages.length === 0 ? (
              <p className="mt-4 text-sm text-muted">Không có tin nhắn.</p>
            ) : (
              <ol className="mt-3 space-y-2 overflow-y-auto" aria-label="Tin nhắn">
                {result.messages.map((message) => {
                  const customer = message.senderRole === "CUSTOMER";
                  return (
                    <li key={message.id} className={customer ? "pr-10" : "pl-10"}>
                      <div
                        className={`rounded-xl px-3 py-2 text-sm ${
                          customer ? "bg-canvas text-ink" : "bg-brand/10 text-ink"
                        }`}
                      >
                        <p className="text-xs font-medium text-muted">
                          {message.senderName} · {customer ? "Khách hàng" : partnerLabel} ·{" "}
                          {formatOpsDateTime(message.createdAt)}
                        </p>
                        <p className="mt-0.5 whitespace-pre-wrap break-words">{message.body}</p>
                      </div>
                    </li>
                  );
                })}
              </ol>
            )}
          </div>
        </div>
      ) : null}
    </>
  );
}
