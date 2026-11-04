import React, { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { SearchSelect, type SearchSelectOption } from "@/components/ui/search-select";
import { focusRing } from "@/lib/admin-format";
import { toast } from "sonner";
import { ApiError } from "@/lib/api/errors";
import { createNotificationCampaign } from "../api";
import { useQueryClient } from "@tanstack/react-query";

const CHANNEL_OPTIONS: readonly SearchSelectOption[] = [
  { value: "PUSH", label: "Push Notification" },
  { value: "IN_APP", label: "In-app Notice" },
  { value: "EMAIL", label: "Email" },
  { value: "SMS", label: "SMS" },
];

const AUDIENCE_OPTIONS: readonly SearchSelectOption[] = [
  { value: "ALL", label: "Tất cả người dùng" },
  { value: "CUSTOMER", label: "Khách hàng" },
  { value: "DRIVER", label: "Tài xế" },
  { value: "MERCHANT", label: "Đối tác quán" },
  { value: "STAFF", label: "Nhân sự vận hành" },
];

interface NotificationsCreateModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function NotificationsCreateModal({
  isOpen,
  onClose,
}: NotificationsCreateModalProps) {
  const queryClient = useQueryClient();
  const [createTitle, setCreateTitle] = useState("");
  const [createBody, setCreateBody] = useState("");
  const [createChannel, setCreateChannel] = useState<
    "PUSH" | "IN_APP" | "EMAIL" | "SMS"
  >("PUSH");
  const [createAudience, setCreateAudience] = useState<
    "ALL" | "CUSTOMER" | "DRIVER" | "MERCHANT" | "STAFF"
  >("ALL");
  const [createReason, setCreateReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    const trimmedReason = createReason.trim();
    if (trimmedReason.length < 5) {
      toast.error(
        "Vui lòng nhập lý do tạo chiến dịch (tối thiểu 5 ký tự) để phục vụ kiểm toán.",
      );
      return;
    }

    setIsSubmitting(true);
    try {
      const created = await createNotificationCampaign({
        title: createTitle.trim(),
        body: createBody.trim(),
        channels: [createChannel],
        audience: createAudience,
        reason: trimmedReason,
      });
      toast.success(`Đã tạo bản nháp chiến dịch ${created.code ?? ""}`);
      onClose();
      setCreateTitle("");
      setCreateBody("");
      setCreateReason("");
      void queryClient.invalidateQueries({
        queryKey: ["ops", "notifications"],
      });
    } catch (err) {
      toast.error(
        err instanceof ApiError ? err.message : "Không thể tạo chiến dịch.",
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
          <div>
            <h3 className="text-lg font-bold text-ink">
              Tạo chiến dịch thông báo mới
            </h3>
            <p className="text-xs text-muted">
              Lưu bản nháp trên Nest — không gửi OTP / mã xác thực qua CMS.
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

        <form className="mt-4 space-y-3" onSubmit={handleSubmit}>
          <label className="block text-xs font-medium text-muted">
            Tiêu đề
            <input
              required
              minLength={3}
              maxLength={160}
              value={createTitle}
              onChange={(event) => setCreateTitle(event.target.value)}
              className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              placeholder="VD: Cập nhật điều khoản dịch vụ DealGo Food"
            />
          </label>
          <label className="block text-xs font-medium text-muted">
            Nội dung
            <textarea
              required
              minLength={3}
              maxLength={2000}
              rows={4}
              value={createBody}
              onChange={(event) => setCreateBody(event.target.value)}
              className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`}
              placeholder="Nội dung gửi đến người dùng…"
            />
          </label>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <SearchSelect
                label="Kênh"
                icon="bell"
                value={createChannel}
                options={CHANNEL_OPTIONS}
                placeholder="Chọn kênh thông báo"
                onChange={(val) => {
                  if (val) setCreateChannel(val as "PUSH" | "IN_APP" | "EMAIL" | "SMS");
                }}
              />
            </div>
            <div>
              <SearchSelect
                label="Đối tượng"
                icon="users"
                value={createAudience}
                options={AUDIENCE_OPTIONS}
                placeholder="Chọn đối tượng nhận"
                onChange={(val) => {
                  if (val) setCreateAudience(val as "ALL" | "CUSTOMER" | "DRIVER" | "MERCHANT" | "STAFF");
                }}
              />
            </div>
          </div>

          <label className="block text-xs font-medium text-muted">
            Lý do tạo chiến dịch (Bắt buộc cho kiểm toán)
            <textarea
              required
              minLength={5}
              maxLength={500}
              rows={2}
              value={createReason}
              onChange={(event) => setCreateReason(event.target.value)}
              className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`}
              placeholder="VD: Thông báo bảo trì hạ tầng theo quyết định TechOps-102…"
            />
          </label>

          <div className="flex items-center justify-end gap-2 pt-3">
            <button
              type="button"
              disabled={isSubmitting}
              onClick={onClose}
              className="rounded-xl border border-border px-4 py-2 text-xs font-semibold text-ink hover:bg-canvas cursor-pointer disabled:opacity-60"
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={isSubmitting || createReason.trim().length < 5}
              className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-4 py-2 text-xs font-semibold text-white hover:bg-brand/90 cursor-pointer disabled:opacity-60"
            >
              <OpsIcon name="plus" className="size-4" />
              {isSubmitting ? "Đang tạo…" : "Tạo bản nháp"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
