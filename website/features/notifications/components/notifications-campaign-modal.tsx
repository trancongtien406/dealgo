import React, { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/lib/admin-format";
import { toast } from "sonner";
import { ApiError } from "@/lib/api/errors";
import { approveNotificationCampaign, type CampaignItem } from "../api";
import { useQueryClient } from "@tanstack/react-query";
import { NotificationCampaignStatusChip } from "./notification-status-chip";

interface NotificationsCampaignModalProps {
  campaign: CampaignItem | null;
  onClose: () => void;
}

export function NotificationsCampaignModal({
  campaign,
  onClose,
}: NotificationsCampaignModalProps) {
  const queryClient = useQueryClient();
  const [approvalReason, setApprovalReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!campaign) return null;

  const handleApprove = async () => {
    const trimmedReason = approvalReason.trim();
    if (trimmedReason.length < 5) {
      toast.error(
        "Vui lòng nhập lý do phê duyệt (tối thiểu 5 ký tự) để phục vụ kiểm toán.",
      );
      return;
    }

    setIsSubmitting(true);
    try {
      await approveNotificationCampaign(campaign.code, trimmedReason);
      toast.success(`Đã phê duyệt chiến dịch ${campaign.code}`);
      onClose();
      setApprovalReason("");
      void queryClient.invalidateQueries({
        queryKey: ["ops", "notifications"],
      });
    } catch (err) {
      toast.error(
        err instanceof ApiError
          ? err.message
          : "Không thể phê duyệt chiến dịch.",
      );
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
              {campaign.body ??
                "Nội dung thông báo hệ thống tự động từ DealGo."}
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
          {campaign.status === "PENDING_APPROVAL" ? (
            <div className="w-full space-y-2">
              <label className="block text-xs font-medium text-muted">
                Lý do phê duyệt (Bắt buộc cho kiểm toán)
                <textarea
                  value={approvalReason}
                  onChange={(event) => setApprovalReason(event.target.value)}
                  minLength={5}
                  maxLength={500}
                  rows={2}
                  placeholder="Nhập lý do hoặc mã quyết định phê duyệt chiến dịch phát hành…"
                  className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`}
                />
              </label>
              <button
                type="button"
                disabled={isSubmitting || approvalReason.trim().length < 5}
                onClick={handleApprove}
                className="inline-flex w-full items-center justify-center gap-1.5 rounded-xl bg-brand px-3.5 py-2 text-xs font-semibold text-white hover:bg-brand/90 cursor-pointer disabled:opacity-60"
              >
                <OpsIcon name="check" className="size-4" />
                {isSubmitting
                  ? "Đang phê duyệt…"
                  : "Xác nhận duyệt & phát hành"}
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl border border-border px-4 py-2 text-xs font-semibold text-ink hover:bg-canvas cursor-pointer"
            >
              Đóng
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
