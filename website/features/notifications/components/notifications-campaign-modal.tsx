import React, { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/lib/admin-format";
import { toast } from "sonner";
import { ApiError } from "@/lib/api/errors";
import {
  approveNotificationCampaign,
  cancelNotificationCampaign,
  rejectNotificationCampaign,
  submitNotificationCampaign,
  type CampaignItem,
} from "../api";
import { useQueryClient } from "@tanstack/react-query";
import { NotificationCampaignStatusChip } from "./notification-status-chip";

interface NotificationsCampaignModalProps {
  campaign: CampaignItem | null;
  onClose: () => void;
}

type CampaignAction = "submit" | "approve" | "reject" | "cancel";

const REASON_MIN = 5;

const actionCopy: Record<CampaignAction, { done: string; failed: string }> = {
  submit: { done: "Đã gửi duyệt chiến dịch", failed: "Không thể gửi duyệt chiến dịch." },
  approve: { done: "Đã phê duyệt chiến dịch", failed: "Không thể phê duyệt chiến dịch." },
  reject: { done: "Đã trả chiến dịch về bản nháp", failed: "Không thể từ chối chiến dịch." },
  cancel: { done: "Đã huỷ chiến dịch", failed: "Không thể huỷ chiến dịch." },
};

/** Which workflow buttons a status offers (Nest notification.controller transitions). */
export function campaignActionsFor(status: CampaignItem["status"]): CampaignAction[] {
  switch (status) {
    case "DRAFT":
      return ["submit", "cancel"];
    case "PENDING_APPROVAL":
      return ["approve", "reject", "cancel"];
    case "RUNNING":
      return ["cancel"];
    default:
      return [];
  }
}

export function NotificationsCampaignModal({
  campaign,
  onClose,
}: NotificationsCampaignModalProps) {
  const queryClient = useQueryClient();
  const [approvalReason, setApprovalReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!campaign) return null;

  const actions = campaignActionsFor(campaign.status);
  const needsReason = actions.some((action) => action !== "submit");
  const trimmedReason = approvalReason.trim();
  const reasonOk = trimmedReason.length >= REASON_MIN;

  const run = async (action: CampaignAction) => {
    if (action !== "submit" && !reasonOk) {
      toast.error(
        `Vui lòng nhập lý do (tối thiểu ${REASON_MIN} ký tự) để phục vụ kiểm toán.`,
      );
      return;
    }
    setIsSubmitting(true);
    try {
      if (action === "submit") {
        await submitNotificationCampaign(campaign.code, trimmedReason || undefined);
      } else if (action === "approve") {
        await approveNotificationCampaign(campaign.code, trimmedReason);
      } else if (action === "reject") {
        await rejectNotificationCampaign(campaign.code, trimmedReason);
      } else {
        await cancelNotificationCampaign(campaign.code, trimmedReason);
      }
      toast.success(`${actionCopy[action].done} ${campaign.code}`);
      onClose();
      setApprovalReason("");
      void queryClient.invalidateQueries({
        queryKey: ["ops", "notifications"],
      });
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : actionCopy[action].failed);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <div
        className="fixed inset-0 bg-ink/40 backdrop-blur-xs transition-opacity"
        onClick={() => {
          if (!isSubmitting) onClose();
        }}
      />
      <div className="relative z-10 w-full max-w-lg overflow-hidden rounded-2xl border border-border bg-white p-6 shadow-2xl transition-all">
        <div className="flex items-start justify-between gap-3 border-b border-border pb-4">
          <div className="min-w-0">
            <span className="inline-block rounded-md bg-brand/10 px-2 py-0.5 text-xs font-bold text-brand">
              {campaign.code}
            </span>
            <h3 className="mt-1 text-lg font-bold text-ink truncate">
              {campaign.title}
            </h3>
            <p className="text-xs text-muted">
              Kênh: {campaign.channel} · Đối tượng: {campaign.audience}
            </p>
          </div>
          <button
            type="button"
            disabled={isSubmitting}
            onClick={onClose}
            className="rounded-lg p-1 text-muted hover:bg-canvas hover:text-ink cursor-pointer disabled:opacity-60"
          >
            <OpsIcon name="close" className="size-5" />
          </button>
        </div>

        <div className="mt-4 space-y-4 text-sm">
          <div className="rounded-xl border border-border bg-canvas/70 p-4">
            <p className="text-xs font-semibold text-muted uppercase">
              Nội dung thông báo gửi người dùng
            </p>
            <p className="mt-2 text-sm font-medium leading-relaxed text-ink break-words whitespace-pre-line">
              {campaign.body?.trim() ? campaign.body : "—"}
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs">
            <div className="rounded-xl border border-border p-3">
              <span className="text-muted">Thời điểm lên lịch:</span>
              <p className="mt-0.5 font-semibold text-ink">
                {campaign.schedule}
              </p>
            </div>
            <div className="rounded-xl border border-border p-3">
              <span className="text-muted">Đã tiếp cận:</span>
              <p className="mt-0.5 font-semibold text-ink">
                {campaign.reached === "—"
                  ? "Chưa phát hành"
                  : `${campaign.reached} lượt`}
              </p>
            </div>
          </div>

          <div className="rounded-xl border border-border p-3 text-xs">
            <span className="text-muted">Trạng thái vận hành:</span>
            <div className="mt-1 flex items-center justify-between">
              <NotificationCampaignStatusChip status={campaign.status} />
              <span className="text-muted">ID: {campaign.code}</span>
            </div>
          </div>
        </div>

        <div className="mt-6 flex flex-wrap items-center justify-end gap-2 border-t border-border pt-4">
          {needsReason ? (
            <label className="block w-full text-xs font-medium text-muted">
              {actions.includes("submit")
                ? "Ghi chú (tuỳ chọn khi gửi duyệt, bắt buộc khi huỷ)"
                : "Lý do (bắt buộc cho kiểm toán)"}
              <textarea
                value={approvalReason}
                onChange={(event) => setApprovalReason(event.target.value)}
                maxLength={500}
                rows={2}
                placeholder="Nhập lý do hoặc mã quyết định…"
                className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`}
              />
            </label>
          ) : null}
          {actions.includes("cancel") ? (
            <button
              type="button"
              disabled={isSubmitting || !reasonOk}
              onClick={() => void run("cancel")}
              className="rounded-xl border border-danger/40 px-3.5 py-2 text-xs font-semibold text-danger hover:bg-danger/5 cursor-pointer disabled:opacity-60"
            >
              Huỷ chiến dịch
            </button>
          ) : null}
          {actions.includes("reject") ? (
            <button
              type="button"
              disabled={isSubmitting || !reasonOk}
              onClick={() => void run("reject")}
              className="rounded-xl border border-border px-3.5 py-2 text-xs font-semibold text-ink hover:bg-canvas cursor-pointer disabled:opacity-60"
            >
              Từ chối (về bản nháp)
            </button>
          ) : null}
          {actions.includes("submit") ? (
            <button
              type="button"
              disabled={isSubmitting}
              onClick={() => void run("submit")}
              className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3.5 py-2 text-xs font-semibold text-white hover:bg-brand/90 cursor-pointer disabled:opacity-60"
            >
              <OpsIcon name="check" className="size-4" />
              {isSubmitting ? "Đang gửi…" : "Gửi duyệt"}
            </button>
          ) : null}
          {actions.includes("approve") ? (
            <button
              type="button"
              disabled={isSubmitting || !reasonOk}
              onClick={() => void run("approve")}
              className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3.5 py-2 text-xs font-semibold text-white hover:bg-brand/90 cursor-pointer disabled:opacity-60"
            >
              <OpsIcon name="check" className="size-4" />
              {isSubmitting ? "Đang phê duyệt…" : "Xác nhận duyệt & phát hành"}
            </button>
          ) : null}
          {actions.length === 0 ? (
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl border border-border px-4 py-2 text-xs font-semibold text-ink hover:bg-canvas cursor-pointer"
            >
              Đóng
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
